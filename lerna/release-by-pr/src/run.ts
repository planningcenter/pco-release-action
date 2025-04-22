import { Octokit } from '@octokit/action'
import { easyExec } from '../../../shared/utils.js'
import { setOutput } from '@actions/core'

type ReleaseType = 'patch' | 'minor' | 'major' | undefined
type Inputs = { releaseType: ReleaseType; installCommand: string }
type Label = { id: string }
type PullRequest<Label extends Record<string, any> = { id: string; name: string; number: number }> = {
  id: string
  number: number
  labels: { nodes: Label[] }
}
type LabelIds = Record<'labelPendingId' | 'labelMajorId', string>

const LABEL_NAMES = { labelPending: 'pco-release-pending', labelMajor: 'pco-release-major' }

const FETCH_QUERY = `
  query($owner:String!, $repo:String!, $mainBranch:String!, $releaseBranch:String!, $lastRelease: String!) {
    repository(owner: $owner, name: $repo) {
      id
      lastRelease: release(tagName: $lastRelease) {
        tag {
          compare(headRef: $mainBranch) {
            commits(first: 100) {
              nodes {
                author {
                  name
                  user {
                    id
                  }
                }
              }
            }
          }
        }
      }
      releaseBranch: ref(qualifiedName: $releaseBranch) {
        id
        target {
          oid
        }
        associatedPullRequests(first: 1, states: OPEN) {
          nodes {
            id
            number
            labels(first: 25) {
              nodes {
                id
                name
              }
            }
          }
        }
      }
      labelPending: label(name: "${LABEL_NAMES.labelPending}") {
        id
      }
      labelMajor: label(name: "${LABEL_NAMES.labelMajor}") {
        id
      }
    }
  }
`

const { GITHUB_REPOSITORY, GITHUB_WORKSPACE } = process.env
if (!GITHUB_REPOSITORY) throw new Error('GITHUB_REPOSITORY is not set')
const [owner, repo] = GITHUB_REPOSITORY.split('/')
const octokit = new Octokit()
const LERNA = `${GITHUB_WORKSPACE}/node_modules/.bin/lerna`

export const run = async (inputs: Inputs): Promise<void> => {
  const MAIN_BRANCH = 'main'
  const RELEASE_BRANCH = 'pco-release--internal'

  // Find the last release version from main branch
  await easyExec(`git fetch origin`)
  // If there are no changes, exit
  await easyExec(`git checkout ${MAIN_BRANCH}`)
  const lastReleaseVersion = (await easyExec(`jq -r .version ./lerna.json`)).output.split('\n')[0]
  try {
    await easyExec(`git fetch origin --tags`)
    const diff = await easyExec(`git diff origin/${MAIN_BRANCH}..refs/tags/v${lastReleaseVersion}`)
    if (diff.exitCode !== 0) throw diff
    if (diff.output === '') {
      console.log('No changes detected. Exiting...')
      return
    }
  } catch (e) {
    console.log(
      `Could not find a release for v${lastReleaseVersion}. This often happens when merging a new release.
      If this happens unexpectedly, make sure there is a release labeled "v${lastReleaseVersion}" and try again.`,
      e,
    )
    return
  }

  await easyExec(inputs.installCommand)

  // Fetch information needed about the repo
  const response: {
    repository: {
      id: string
      mainBranch: { target: { oid: string }; compare: { commits: { nodes: { author: { user: { id: string } } }[] } } }
      releaseBranch: { id: string; target: { oid: string }; associatedPullRequests: { nodes: PullRequest[] } }
      lastRelease: { tag: { compare: { commits: { nodes: { author: { name: string; user: { id: string } } }[] } } } }
      labelPending: Label
      labelPatch: Label
      labelMinor: Label
      labelMajor: Label
    }
  } = await octokit.graphql(FETCH_QUERY, {
    owner,
    repo,
    mainBranch: MAIN_BRANCH,
    releaseBranch: RELEASE_BRANCH,
    lastRelease: `v${lastReleaseVersion}`,
  })
  const { releaseBranch, id, labelPending, lastRelease, labelMajor } = response.repository
  const pullRequests = releaseBranch?.associatedPullRequests.nodes || []
  let pullRequest: PullRequest

  // Find or create labels
  const { labelPendingId, labelMajorId } = await findOrCreateLabels(
    { labelPending, labelMajor },
    { octokit, repoId: id },
  )

  // Setup git
  await easyExec(`git config --global user.email "github-actions[bot]@users.noreply.github.com"`)
  await easyExec(`git config --global user.name "github-actions[bot]"`)

  // Create release branch if it doesn't exist
  if (!releaseBranch) await easyExec(`git checkout -b ${RELEASE_BRANCH}`)

  // Update the release branch with the latest main (but keep our release branch changes)
  await easyExec(`git checkout ${RELEASE_BRANCH}`)
  await easyExec(`git reset --hard origin/${MAIN_BRANCH}`)

  // Bump the version, editing the last commit (which should be the version bump)
  const forceMajor = pullRequests.length > 0 && pullRequests[0].labels.nodes.find((label) => label.id === labelMajorId)
  if (forceMajor) inputs.releaseType = 'major'
  const specificVersion = inputs.releaseType ? [`${inputs.releaseType}`] : []
  const updateVersionCommandFlags = [...specificVersion, '--no-push', '--json', '-y']
  const updateVersionCommand = `${LERNA} version ${updateVersionCommandFlags.join(' ')}`
  const updateVersionOutput = (await easyExec(`${updateVersionCommand}"`)).output
  let updatedPackages

  try {
    updatedPackages = (
      JSON.parse(updateVersionOutput) as { newVersion: string; name: string; private: boolean; location: string }[]
    ).sort((a, b) => (a.private === b.private ? 0 : a.private ? 1 : -1))
  } catch {
    console.log('No changes detected. Exiting...')
    return
  }

  // See if any of the changes are something that would require a release. If not, let's exit early.
  if (!updatedPackages || updatedPackages.length === 0) {
    console.log('No changes detected. Exiting...')
    return
  }

  await easyExec(`git push -f --set-upstream origin ${RELEASE_BRANCH}`)

  // Track the changelog changes for the PR body before it is reset
  const updatedChangelog = (
    await Promise.all(
      updatedPackages.map(async (updatedPackage) => {
        const diff = (
          await easyExec(`git diff origin/${MAIN_BRANCH} -- ${updatedPackage.location}/CHANGELOG.md`)
        ).output
          .split('\n')
          .filter((line) => line.startsWith('+') && !line.startsWith('+++'))
          .map((line) => line.substring(1))
          .join('\n')
        if (diff) {
          return `# ${updatedPackage.name}\n${diff}\n`
        }
        return ''
      }),
    )
  ).join('\n')

  // If there are no changes, exit
  try {
    await easyExec(`git fetch origin --tags`)
    const diff = await easyExec(`git diff origin/${MAIN_BRANCH}..refs/tags/v${lastReleaseVersion}`)
    if (diff.exitCode !== 0) throw diff
    if (diff.output === '') return
  } catch (e) {
    console.log(
      `Could not find a release for v${lastReleaseVersion}. This often happens when merging a new release.
      If this happens unexpectedly, make sure there is a release labeled "v${lastReleaseVersion}" and try again.`,
      e,
    )
    return
  }

  // Set up the release branch and tag to be pushed with minimal changes
  const version = updatedPackages[0].newVersion

  // Create or update pull request
  if (pullRequests.length === 0) {
    pullRequest = await createPullRequest({
      labelPendingId,
      repoId: id,
      releaseBranch: RELEASE_BRANCH,
      mainBranch: MAIN_BRANCH,
      version,
      lastReleaseVersion: `v${lastReleaseVersion}`,
      changelog: updatedChangelog,
    })
  } else {
    await updatePullRequest({
      pullRequest: pullRequests[0],
      version,
      lastReleaseVersion: `v${lastReleaseVersion}`,
      changelog: updatedChangelog,
    })
    pullRequest = pullRequests[0]
  }

  // Set the pull request number as an output
  setOutput('pull_request_id', pullRequest.number)

  // Request reviews from authors of commits
  await requestReviewsFromAuthors({ prId: pullRequest.id, commits: lastRelease.tag.compare.commits.nodes })
}

const FOOTER = `## 🚀 PCO-Release

  This PR was automatically generated by pco-release-action.
  Merging it will create a new release.

  ### Actions
  - The version bump type is determined via [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).
  - Release candidates are automatically created when this PR is updated. To deploy the release candidate to staging, add a comment \`pco deploy staging\`.
  `

async function findOrCreateLabels(
  labels: Record<keyof typeof LABEL_NAMES, Label>,
  { octokit, repoId }: { octokit: Octokit; repoId: string },
): Promise<LabelIds> {
  const result: Partial<LabelIds> = {}
  for (const key in labels) {
    const typedKey = key as keyof typeof LABEL_NAMES
    const label = labels[typedKey]
    const keyId = `${key}Id` as keyof LabelIds
    if (label) {
      result[keyId] = label.id
    } else {
      const {
        createLabel: { label },
      } = await octokit.graphql<{ createLabel: { label: Label } }>(
        `mutation($repoId: ID!, $name: String!) { createLabel(input: { repositoryId: $repoId, name: $name, color: "dddddd" }) { label { id } } }`,
        { repoId, name: LABEL_NAMES[typedKey] },
      )

      result[keyId] = label.id
    }
  }

  return result as LabelIds
}

async function createPullRequest({
  labelPendingId,
  repoId,
  releaseBranch,
  mainBranch,
  version,
  lastReleaseVersion,
  changelog,
}: {
  labelPendingId: string
  repoId: string
  releaseBranch: string
  mainBranch: string
  version: string
  lastReleaseVersion: string
  changelog: string
}) {
  // Create a pull request
  const {
    createPullRequest: { pullRequest },
  } = await octokit.graphql<{ createPullRequest: { pullRequest: PullRequest } }>(
    `mutation($repoId: ID!, $baseRefName: String!, $headRefName: String!, $body: String!, $title: String!) {
        createPullRequest(input: { repositoryId: $repoId, baseRefName: $baseRefName, headRefName: $headRefName, body: $body, title: $title}) {
          pullRequest {
            id
            number
          }
        }
      }`,
    {
      repoId,
      headRefName: `refs/heads/${releaseBranch}`,
      baseRefName: `refs/heads/${mainBranch}`,
      body: buildBody({ version, lastReleaseVersion, changelog }),
      title: `v${version}`,
    },
  )

  // add pending label
  await octokit.graphql(
    `mutation($prId: ID!, $labelId: ID!) { addLabelsToLabelable(input: {labelIds: [$labelId], labelableId: $prId}) { clientMutationId} }`,
    { prId: pullRequest.id, labelId: labelPendingId },
  )
  return pullRequest
}

function buildBody({
  lastReleaseVersion,
  changelog,
}: {
  version: string
  lastReleaseVersion: string
  changelog: string
}): string {
  if (changelog === '') return `No changes found\n\n${FOOTER}`

  return `${changelog}\n\n[Full Changes](https://github.com/${owner}/${repo}/compare/${lastReleaseVersion}...main)\n\n${FOOTER}`
}

async function updatePullRequest({
  pullRequest,
  version,
  lastReleaseVersion,
  changelog,
}: {
  pullRequest: PullRequest
  version: string
  lastReleaseVersion: string
  changelog: string
}) {
  return await octokit.graphql(
    `mutation($prId: ID!, $body: String, $title: String) { updatePullRequest(input: { pullRequestId: $prId, body: $body, title: $title}) { clientMutationId} }`,
    {
      prId: pullRequest.id,
      body: buildBody({ version, lastReleaseVersion, changelog }),
      title: `v${version}`,
    },
  )
}

async function requestReviewsFromAuthors({
  prId,
  commits,
}: {
  prId: string
  commits: { author: { name: string; user: { id: string } } }[]
}) {
  await octokit.graphql(
    `mutation($prId: ID!, $userIds: [ID!]) { requestReviews(input: {pullRequestId: $prId, userIds: $userIds, union: true}) { clientMutationId } }`,
    {
      prId,
      userIds: [
        ...new Set(
          commits
            .filter((commit) => !commit.author.name.includes('[bot]'))
            .map((commit) => commit.author.user.id)
            .filter((id) => id),
        ),
      ],
    },
  )
}
