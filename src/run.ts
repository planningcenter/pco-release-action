import * as core from '@actions/core'
import { Octokit } from '@octokit/action'
import { easyExec } from './utils.js'

type Inputs = {
  name: string
}

const FETCH_QUERY = `
  query($owner:String!, $repo:String!, $mainBranch:String!, $releaseBranch:String!) {
    repository(owner: $owner, name: $repo) {
      id
      mainBranch: ref(qualifiedName: $mainBranch) {
        id
        target {
          oid
        }
      }
      releaseBranch: ref(qualifiedName: $releaseBranch) {
        id
        target {
          oid
        }
      }
      pullRequests(first: 1, states: [OPEN], labels: ["pco-release-pending"], orderBy: { field: CREATED_AT, direction: DESC }) {
        nodes {
          id
          title
          labels(first: 10) {
            nodes: {
              id
              name
            }
          }
        }
      }
    }
  }
`

export const run = async (inputs: Inputs): Promise<void> => {
  const MAIN_BRANCH = 'main'
  const RELEASE_BRANCH = 'pco-release--internal'
  const { GITHUB_REPOSITORY, GITHUB_WORKSPACE } = process.env
  const octokit = new Octokit()
  if (!GITHUB_REPOSITORY) {
    throw new Error('GITHUB_REPOSITORY is not set')
  }
  const [owner, repo] = GITHUB_REPOSITORY.split('/')
  const releaseType = 'patch'
  const response: {
    data: {
      repository: {
        id: string
        mainBranch: { target: { oid: string } }
        releaseBranch: { id: string; target: { oid: string } }
        pullRequests: { nodes: { id: string; title: string; labels: { nodes: { id: string; name: string }[] } }[] }
      }
    }
  } = await octokit.graphql(FETCH_QUERY, { owner, repo, mainBranch: MAIN_BRANCH, releaseBranch: RELEASE_BRANCH })
  const { pullRequests, mainBranch, releaseBranch, id } = response.data.repository

  if (releaseBranch) {
    await octokit.graphql(
      `mutation($owner: String!, $repo: String!, $refId: ID!, $oid: GitObjectID!) {
        updateRef(input: { refId: $refId, oid: $oid, force: true }) {
          id
        }
      }`,
      { owner, repo, refId: releaseBranch.id, oid: mainBranch.target.oid },
    )
    // reset release branch to main branch
  } else {
    await octokit.graphql(
      `mutation($repoId: ID!, $oid: GitObjectID!) {
        createRef(input: { repositoryId: $repoId, oid: $oid, name: $name }) {
          id
        }
      }`,
      { repoId: id, roid: mainBranch.target.oid, name: `refs/heads/${RELEASE_BRANCH}` },
    )
    // create release branch
  }

  // Checkout release branch and update CHANGELOG

  if (pullRequests.nodes.length === 0) {
    easyExec(`cd ${GITHUB_WORKSPACE}`)
    easyExec(`git fetch origin`)
    easyExec(`git checkout ${RELEASE_BRANCH}`)
    easyExec(`yarn version --${releaseType} --no-git-tag-version`)
    const version = (await easyExec(`jq -r .version package.json`)).output
    easyExec(`date=$(date +"%Y-%m-%d")
              awk -v date="$date" '/## Unreleased/ {print; print ""; print "## v${version} - " date; next}1' CHANGELOG.md > temp && mv temp CHANGELOG.md`)
    easyExec(`git add CHANGELOG.md && git commit --amend --no-edit`)
    easyExec(`git push origin ${RELEASE_BRANCH}`)
    await octokit.graphql(
      `mutation($repoId: ID!, $baseRefName: String!, $body: String!) {
        createPullRequest(input: { repositoryId: $repoId, baseRefName: $baseRefName, body: $body }) {
          id
        }
      }`,
      { repoId: id, baseRefName: RELEASE_BRANCH, body: buildBody(), title: `v${version}` },
    )
  } else {
    // upgrade the release version if its a bigger type
  }
}

function buildBody(): string {
  return 'TODO: generated body'
}
