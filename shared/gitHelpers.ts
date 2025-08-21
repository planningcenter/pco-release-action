import { easyExec } from './utils'
import { Octokit } from '@octokit/action'

export async function updateReleaseBranchToMainWithCustomUpdates({
  octokit,
  makeChanges,
  owner,
  repo,
  branchName = 'pco-release--internal',
  refBranchName = `${branchName}-tmp`,
  mainBranch = 'main',
}: {
  octokit: Octokit
  makeChanges: () => Promise<string>
  owner: string
  repo: string
  branchName?: string
  refBranchName?: string
  mainBranch?: string
}) {
  const result = await easyExec(`git checkout -b ${refBranchName}`)
  if (result.exitCode !== 0) await easyExec(`git checkout ${refBranchName}`)
  await easyExec(`git reset --hard origin/${mainBranch}`)

  const version = await makeChanges()

  await easyExec(`git config --global user.email "github-actions[bot]@users.noreply.github.com"`)
  await easyExec(`git config --global user.name "github-actions[bot]"`)
  await easyExec(`git add .`)
  await easyExec(`git commit -m v${version}`)
  await easyExec(`git push origin ${refBranchName}:${refBranchName} --force`)

  const currentSha = (await easyExec('git rev-parse HEAD')).output.trim()

  try {
    await octokit.rest.git.updateRef({
      owner,
      repo,
      ref: `heads/${branchName}`,
      sha: currentSha,
      force: true,
    })
  } catch (updateError) {
    await octokit.rest.git.createRef({
      owner,
      repo,
      ref: `refs/heads/${branchName}`,
      sha: currentSha,
    })
  }

  await easyExec(`git push origin :${refBranchName}`)
  return version
}
