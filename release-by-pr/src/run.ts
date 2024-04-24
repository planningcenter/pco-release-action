import { Octokit } from '@octokit/action'
import { easyExec, readFileContent, replaceTextInFile } from './utils.js'

type ReleaseType = 'patch' | 'minor' | 'major' | 'nochange'
type Inputs = { releaseType: ReleaseType; packageJsonPath: string; versionCommand: string }
type ValueOf<T> = T[keyof T]
type Label = { id: string } | null
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

  // Find the last release version from main branch
  await easyExec(`git fetch origin`)
  await easyExec(`git checkout ${MAIN_BRANCH}`)
  const lastReleaseVersion = (await easyExec(`jq -r .version ${inputs.packageJsonPath}`)).output.split('\n')[0]

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
  const versionBumpType = (inputs.releaseType === 'nochange' ? getReleaseType(pullRequests[0]) : inputs.releaseType) as
    | 'patch'
    | 'minor'
    | 'major'

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

  // Bump version, update changelog, and push to release branch
  await easyExec(`git checkout ${RELEASE_BRANCH}`)
  await easyExec(`git reset --hard origin/${MAIN_BRANCH}`)
  await easyExec(normalizeVersionCommand({ versionCommand: inputs.versionCommand, versionBumpType }))
  const version = (await easyExec(`jq -r .version ${inputs.packageJsonPath}`)).output.split('\n')[0]
  const date = new Date().toISOString().split('T')[0]
  await replaceTextInFile(
    `${GITHUB_WORKSPACE}/CHANGELOG.md`,
    '## Unreleased',
    `## Unreleased\n\n## [v${version}](https://github.com/${owner}/${repo}/releases/tag/v${version}) - ${date}`,
  )
  await easyExec(`git config --global user.email "github-actions[bot]@users.noreply.github.com"`)
  await easyExec(`git config --global user.name "github-actions[bot]"`)
  await easyExec(`git add .`)
  await easyExec(`git commit -m v${version}`)
  await easyExec(`git push origin ${RELEASE_BRANCH} --force`)

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

const FOOTER = `## 🚀 PCO-Release\n\nThis PR was automatically generated by pco-release-action.
  Merging it will create a new release.\n\nTo change the version type, update the label to the
  appropriate type (\`pco-release-patch\`, \`pco-release-minor\`, or \`pco-release-major\`).`

async function findOrCreateLabels(
  labels: Record<keyof typeof LABEL_NAMES, Label>,
  { octokit, repoId }: { octokit: Octokit; repoId: string },
): Promise<LabelIds> {
  const keys = Object.keys(labels)
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
      } = (await octokit.graphql(
        `mutation($repoId: ID!, $name: String!) { createLabel(input: { repositoryId: $repoId, name: $name, color: "dddddd" }) { label { id } } }`,
        { repoId, name: LABEL_NAMES[typedKey] },
      )) as { createLabel: { label: { id: string } } }

      result[keyId] = label.id
    }
  }

  return result as LabelIds
}

function getReleaseType(pullRequest: PullRequest | undefined) {
  if (!pullRequest) return 'patch'

  const releaseType = pullRequest.labels.nodes.find(
    (label) => label.name.startsWith('pco-release-') && label.name !== 'pco-release-pending',
  )
  return releaseType ? releaseType.name.split('-')[2] : 'patch'
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
  } = (await octokit.graphql(
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
  )) as { createPullRequest: { pullRequest: { id: string; labels: { nodes: [] } } } }

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
      labelIds:
        releaseType === 'nochange'
          ? pullRequest.labels.nodes.map((label) => label.id)
          : [
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

function normalizeVersionCommand({
  versionCommand,
  versionBumpType,
}: {
  versionCommand: string
  versionBumpType: ReleaseType
}) {
  if (versionCommand.includes('#{versionBumpType}'))
    return versionCommand.replace('#{versionBumpType}', versionBumpType)

  return `${versionCommand} --${versionBumpType} --no-git-tag-version`
}
