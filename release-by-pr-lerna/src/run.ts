import { Octokit } from '@octokit/action'
import { easyExec, readFileContent } from '../../shared/utils.js'

type ReleaseType = 'patch' | 'minor' | 'major' | undefined
type Inputs = { releaseType: ReleaseType; packageJsonPath: string; versionCommand: string }
type Label = { id: string }
type PullRequest<Label extends Record<string, any> = { id: string; name: string }> = {
  id: string
  labels: { nodes: Label[] }
}
type LabelIds = Record<'labelPendingId' | 'labelPatchId' | 'labelMinorId' | 'labelMajorId', string>

const LABEL_NAMES = {
  labelPending: 'pco-release-pending',
  labelPatch: 'pco-release-patch',
  labelMinor: 'pco-release-minor',
  labelMajor: 'pco-release-major',
}

const FETCH_QUERY = `
  query($owner:String!, $repo:String!, $mainBranch:String!, $releaseBranch:String!, $lastRelease: String!) {
    repository(owner: $owner, name: $repo) {
      id
      mainBranch: ref(qualifiedName: $mainBranch) {
        id
        target {
          oid
        }
      }
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
      labelPatch: label(name: "${LABEL_NAMES.labelPatch}") {
        id
      }
      labelMinor: label(name: "${LABEL_NAMES.labelMinor}") {
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

export const run = async (inputs: Inputs): Promise<void> => {
  const MAIN_BRANCH = 'main'
  const RELEASE_BRANCH = 'pco-release--internal'
  const TEMP_RELEASE_BRANCH = 'pco-release--internal-temp'

  // Find the last release version from main branch
  await easyExec(`git fetch origin`)
  await easyExec(`git checkout ${MAIN_BRANCH}`)
  const lastReleaseVersion = (await easyExec(`jq -r .version ./package.json`)).output.split('\n')[0]
  await easyExec('yarn install')

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
  const { mainBranch, releaseBranch, id, labelPending, labelPatch, labelMajor, labelMinor, lastRelease } =
    response.repository

  // Find or create labels
  const { labelPendingId, labelMajorId, labelMinorId, labelPatchId } = await findOrCreateLabels(
    { labelPending, labelPatch, labelMajor, labelMinor },
    { octokit, repoId: id },
  )

  // Create release branch if it doesn't exist
  if (!releaseBranch) {
    await octokit.graphql(
      `mutation($repoId: ID!, $oid: GitObjectID!, $name: String!) {
        createRef(input: { repositoryId: $repoId, oid: $oid, name: $name }) {
          clientMutationId
        }
      }`,
      { repoId: id, oid: mainBranch.target.oid, name: `refs/heads/${RELEASE_BRANCH}` },
    )
  }

  const pullRequests = releaseBranch?.associatedPullRequests.nodes || []
  let pullRequest: PullRequest

  await easyExec(`git checkout ${TEMP_RELEASE_BRANCH}`)
  await easyExec(`git reset --hard origin/${MAIN_BRANCH}`)
  await easyExec(`git config --global user.email "github-actions[bot]@users.noreply.github.com"`)
  await easyExec(`git config --global user.name "github-actions[bot]"`)
  await easyExec(`git checkout push -f`)
  // const releaseTypeVersionBumpArg = inputs.releaseType ? `${inputs.releaseType}` : ''

  const updateVersionCommandFlags = [
    '--canary',
    // '--no-git-reset',
    '--conventional-prerelease',
    '--conventionalCommits',
    '--createRelease=github',
    '--preid=rc',
    '--dist-tag=next',
    '--json',
    '-y',
  ]
  const updateVersionCommand = `${GITHUB_WORKSPACE}/node_modules/.bin/lerna publish ${updateVersionCommandFlags.join(' ')}`
  const updateVersionOutput = (await easyExec(`${updateVersionCommand}"`)).output

  // If there are no changes, exit
  if (updateVersionOutput.trim().length === 0) {
    console.log('No changes detected. Exiting...')
    return
  }

  const updatedPackages = JSON.parse(updateVersionOutput) as {
    name: string
    version: string
    private: boolean
    location: string
    newVersion: string
  }[]

  const version = updatedPackages[0].newVersion.split('-')[0] // Remove the rc part

  // Now that the version has been updated, commit the changes to the PR branch
  await easyExec(`git checkout ${RELEASE_BRANCH}`)
  await easyExec(`git reset --hard origin/${TEMP_RELEASE_BRANCH}`)

  // Create or update pull request
  if (pullRequests.length === 0) {
    pullRequest = await createPullRequest({
      labelPatchId,
      labelPendingId,
      repoId: id,
      releaseBranch: RELEASE_BRANCH,
      mainBranch: MAIN_BRANCH,
      version,
      lastReleaseVersion: `v${lastReleaseVersion}`,
    })
  } else {
    await updatePullRequest({
      pullRequest: pullRequests[0],
      version,
      releaseType: inputs.releaseType,
      labelMajorId,
      labelMinorId,
      labelPatchId,
      lastReleaseVersion: `v${lastReleaseVersion}`,
    })
    pullRequest = pullRequests[0]
  }

  // Request reviews from authors of commits
  await requestReviewsFromAuthors({ prId: pullRequest.id, commits: lastRelease.tag.compare.commits.nodes })
}

const FOOTER = `## 🚀 PCO-Release

  This PR was automatically generated by pco-release-action.
  Merging it will create a new release.

  ### Actions
  - The version bump type is determined via [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/). If the version bump is incorrect, you can manually update it by adding **\`pco-release-*\` label** (\`pco-release-patch\`, \`pco-release-minor\`, or \`pco-release-major\`) - Change the release type.
  - Release candidates are automatically created when this PR is updated. To deploy the release candidate to staging, add a comment \`@pco-release staging\`.
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
  labelPatchId,
  labelPendingId,
  repoId,
  releaseBranch,
  mainBranch,
  version,
  lastReleaseVersion,
}: {
  labelPatchId: string
  labelPendingId: string
  repoId: string
  releaseBranch: string
  mainBranch: string
  version: string
  lastReleaseVersion: string
}) {
  // Create a pull request
  const {
    createPullRequest: { pullRequest },
  } = await octokit.graphql<{ createPullRequest: { pullRequest: PullRequest } }>(
    `mutation($repoId: ID!, $baseRefName: String!, $headRefName: String!, $body: String!, $title: String!) {
        createPullRequest(input: { repositoryId: $repoId, baseRefName: $baseRefName, headRefName: $headRefName, body: $body, title: $title}) {
          pullRequest {
            id
          }
        }
      }`,
    {
      repoId,
      headRefName: `refs/heads/${releaseBranch}`,
      baseRefName: `refs/heads/${mainBranch}`,
      body: await buildBody({ version, lastReleaseVersion }),
      title: `v${version}`,
    },
  )

  // add patch and pending label
  await octokit.graphql(
    `mutation($prId: ID!, $labelId: ID!) { addLabelsToLabelable(input: {labelIds: [$labelId], labelableId: $prId}) { clientMutationId} }`,
    { prId: pullRequest.id, labelId: labelPatchId },
  )
  await octokit.graphql(
    `mutation($prId: ID!, $labelId: ID!) { addLabelsToLabelable(input: {labelIds: [$labelId], labelableId: $prId}) { clientMutationId} }`,
    { prId: pullRequest.id, labelId: labelPendingId },
  )
  return pullRequest
}

async function buildBody({
  version,
  lastReleaseVersion,
}: {
  version: string
  lastReleaseVersion: string
}): Promise<string> {
  const changelog = await readFileContent(`${GITHUB_WORKSPACE}/CHANGELOG.md`)
  const currentChanges = changelog.split(new RegExp(`##\\s\\[?v?((?!${version})\\d*\\.\\d*\\.\\d*)`))[0]
  const changesMatch = currentChanges.match(new RegExp(`##\\s\\[?v?${version}(\\]\\(.*\\))?\\s(.|\\n)*`, 'm'))
  if (changesMatch === null) return `No changes found\n\n${FOOTER}`

  const changes = changesMatch[0]
  return `${changes}\n\n[Full Changes](https://github.com/${owner}/${repo}/compare/${lastReleaseVersion}...main)\n\n${FOOTER}`
}

async function updatePullRequest({
  pullRequest,
  version,
  releaseType,
  labelMajorId,
  labelMinorId,
  labelPatchId,
  lastReleaseVersion,
}: {
  pullRequest: PullRequest
  version: string
  releaseType: ReleaseType
  labelMajorId: string
  labelMinorId: string
  labelPatchId: string
  lastReleaseVersion: string
}) {
  return await octokit.graphql(
    `mutation($prId: ID!, $body: String, $title: String, $labelIds: [ID!]) { updatePullRequest(input: { pullRequestId: $prId, body: $body, title: $title, labelIds:$labelIds}) { clientMutationId} }`,
    {
      prId: pullRequest.id,
      body: await buildBody({ version, lastReleaseVersion }),
      title: `v${version}`,
      labelIds: [
        ...pullRequest.labels.nodes
          .filter(
            (label) =>
              label.name === 'pco-release-pending' ||
              !Object.values(LABEL_NAMES).includes(label.name) ||
              label.name === `pco-release-${releaseType}`,
          )
          .map((label) => label.id),
        releaseType === 'major' ? labelMajorId : releaseType === 'minor' ? labelMinorId : labelPatchId,
      ],
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
