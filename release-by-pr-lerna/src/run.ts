import { Octokit } from '@octokit/action'
import { easyExec, readFileContent } from '../../shared/utils.js'
import fs from 'fs'

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

  // Find the last release version from main branch
  await easyExec(`git fetch origin`)
  await easyExec(`git checkout ${MAIN_BRANCH}`)
  const lastReleaseVersion = (await easyExec(`jq -r .version ./lerna.json`)).output.split('\n')[0]
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
  const { releaseBranch, id, labelPending, labelPatch, labelMajor, labelMinor, lastRelease } = response.repository

  // Find or create labels
  const { labelPendingId, labelMajorId, labelMinorId, labelPatchId } = await findOrCreateLabels(
    { labelPending, labelPatch, labelMajor, labelMinor },
    { octokit, repoId: id },
  )

  await easyExec(`git config --global user.email "github-actions[bot]@users.noreply.github.com"`)
  await easyExec(`git config --global user.name "github-actions[bot]"`)

  // Create release branch if it doesn't exist
  if (!releaseBranch) {
    // await octokit.graphql(
    //   `mutation($repoId: ID!, $oid: GitObjectID!, $name: String!) {
    //     createRef(input: { repositoryId: $repoId, oid: $oid, name: $name }) {
    //       clientMutationId
    //     }
    //   }`,
    //   { repoId: id, oid: mainBranch.target.oid, name: `refs/heads/${RELEASE_BRANCH}` },
    // )
    await easyExec(`git checkout -b ${RELEASE_BRANCH}`)
    await easyExec(`git commit --allow-empty -m "New release branch"`)
  }

  const pullRequests = releaseBranch?.associatedPullRequests.nodes || []
  let pullRequest: PullRequest

  await easyExec(`git checkout ${RELEASE_BRANCH}`)
  await easyExec(`git rebase origin/${MAIN_BRANCH} --strategy-option=theirs`) // Ensure the release branch is up to date with main

  const updateVersionCommandFlags = [
    '--conventional-prerelease',
    '--conventionalCommits',
    '--createRelease=github',
    '--preid=rc',
    '--amend',
    '--json',
    '-y',
  ]
  const updateVersionCommand = `${GITHUB_WORKSPACE}/node_modules/.bin/lerna version ${updateVersionCommandFlags.join(' ')}`
  const updateVersionOutput = (await easyExec(`${updateVersionCommand}"`)).output

  type UpdatedPackage = { newVersion: string; name: string; private: boolean; location: string }
  let updatedPackages: UpdatedPackage[] | undefined

  try {
    updatedPackages = JSON.parse(updateVersionOutput) as UpdatedPackage[]
    updatedPackages = updatedPackages.sort((a, b) => (a.private === b.private ? 0 : a.private ? 1 : -1))
  } catch (error) {
    console.log('Error parsing JSON', error)
  }

  if (!updatedPackages || updatedPackages.length === 0) {
    console.log('No changes detected. Exiting...')
    return
  }

  const version = updatedPackages[0].newVersion.split('-')[0] // Remove the rc part

  let updatedChangelog = ''

  await Promise.all(
    updatedPackages.map(async (updatedPackage) => {
      const diff = (await easyExec(`git diff origin/${MAIN_BRANCH} -- ${updatedPackage.location}/CHANGELOG.md`)).output
        .split('\n')
        .filter((line) => line.startsWith('+') && !line.startsWith('+++'))
        .map((line) => line.substring(1))
        .join('\n')
      if (diff) {
        updatedChangelog += `# ${updatedPackage.name}\n${diff}\n`
      }
    }),
  )

  await easyExec(`git reset origin/${MAIN_BRANCH} ./**/CHANGELOG.md ./CHANGELOG.md`) // Reset the changelogs because we don't want it littered with rc versions
  // Push the changes to the release branch
  await easyExec(`git commit --amend --no-edit -m "v${version}"`)
  await easyExec(`git push -f --set-upstream origin ${RELEASE_BRANCH}`)

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
      changelog: updatedChangelog,
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
      changelog: updatedChangelog,
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
  changelog,
}: {
  labelPatchId: string
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
  releaseType,
  labelMajorId,
  labelMinorId,
  labelPatchId,
  lastReleaseVersion,
  changelog,
}: {
  pullRequest: PullRequest
  version: string
  releaseType: ReleaseType
  labelMajorId: string
  labelMinorId: string
  labelPatchId: string
  lastReleaseVersion: string
  changelog: string
}) {
  return await octokit.graphql(
    `mutation($prId: ID!, $body: String, $title: String, $labelIds: [ID!]) { updatePullRequest(input: { pullRequestId: $prId, body: $body, title: $title, labelIds:$labelIds}) { clientMutationId} }`,
    {
      prId: pullRequest.id,
      body: buildBody({ version, lastReleaseVersion, changelog }),
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
