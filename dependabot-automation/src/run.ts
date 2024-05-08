import { easyExec, readFileContent, saveFileContent } from '../../shared/utils.js'

import path from 'path'

type Inputs = { changelogPath: string }

const { GITHUB_WORKSPACE } = process.env

export const run = async (inputs: Inputs): Promise<void> => {
  const commitMessage = (await easyExec(`git log -1 --pretty=format:"%s"`)).output.replace(/^"/, '').replace(/"$/, '')
  const changelogLocation = path.join(GITHUB_WORKSPACE as string, inputs.changelogPath)
  const changelog = await readFileContent(changelogLocation)
  const updatedChangelog = updateChangelog({ changelog, message: commitMessage.replace(/^.*?:\s*/, '') })
  saveFileContent(changelogLocation, updatedChangelog)

  await easyExec(`git config --global user.email "github-actions[bot]@users.noreply.github.com"`)
  await easyExec(`git config --global user.name "github-actions[bot]"`)
  await easyExec(`git add .`)
  await easyExec(`git commit -m "update changelog"`)
  await easyExec(`git push`)
}

export function updateChangelog({ changelog, message }: { changelog: string; message: string }) {
  const entryTitle = '## Unreleased'
  const beginning = changelog.indexOf(entryTitle) + entryTitle.length
  const unchangedIntro = changelog.slice(0, beginning)
  const remaining = changelog.slice(beginning)
  const startOfOldReleases = remaining.search(/^##(?!\#)/gm) + beginning
  const currentRelease = changelog.slice(beginning, startOfOldReleases)
  const oldReleases = changelog.slice(startOfOldReleases)

  if (currentRelease.includes('### Dependencies')) {
    const updatedCurrentRelease = currentRelease.replace(
      /([\s\S]*###\sDependencies\n)([\s\S]*?)(\n\n.*)/gm,
      `$1$2\n- ${message}$3`,
    )
    return `${unchangedIntro}${updatedCurrentRelease}${oldReleases}`
  } else {
    return `${unchangedIntro}${currentRelease || '\n\n'}### Dependencies\n\n- ${message}\n\n${oldReleases}`
  }
}
