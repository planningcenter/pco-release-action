import { easyExec, readFileContent, replaceTextInFile } from '../../shared/utils.js'
import path from 'path'

type Inputs = { changelogPath: string }

const { GITHUB_WORKSPACE } = process.env

if (!GITHUB_WORKSPACE) throw 'GITHUB_WORKSPACE is not defined'

export const run = async (inputs: Inputs): Promise<void> => {
  const commitMessage = (await easyExec(`git log -1 --pretty=format:"%s"`)).output.replace(/^"/, '').replace(/"$/, '')
  const changelog = await readFileContent(path.join(GITHUB_WORKSPACE, inputs.changelogPath))
  const entry = `- ${commitMessage.replace(/^.*?:\s*/, '')}`

  // Find the index of "## Unreleased" in the changelog
  const unreleasedIndex = changelog.indexOf('## Unreleased')
  if (unreleasedIndex !== -1) {
    // Check if "### Dependencies" section exists
    const dependenciesIndex = changelog.indexOf('### Dependencies', unreleasedIndex)
    if (dependenciesIndex !== -1) {
      // Add entry below "### Dependencies" section
      const insertIndex = dependenciesIndex + '### Dependencies'.length
      const updatedChangelog = changelog.slice(0, insertIndex) + `\n${entry}` + changelog.slice(insertIndex)
      await replaceTextInFile(`${GITHUB_WORKSPACE}/${inputs.changelogPath}`, changelog, updatedChangelog)
    } else {
      // Create "### Dependencies" section and add entry below it
      const updatedChangelog =
        changelog.slice(0, unreleasedIndex) + `### Dependencies\n\n${entry}\n\n` + changelog.slice(unreleasedIndex)
      await replaceTextInFile(`${GITHUB_WORKSPACE}/${inputs.changelogPath}`, changelog, updatedChangelog)
    }
  }

  await easyExec(`git config --global user.email "github-actions[bot]@users.noreply.github.com"`)
  await easyExec(`git config --global user.name "github-actions[bot]"`)
  await easyExec(`git add .`)
  await easyExec(`git commit -m "update changelog"`)
  await easyExec(`git push`)
}
