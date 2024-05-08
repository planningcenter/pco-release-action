import * as core from '@actions/core'
import { run } from './run.js'

const main = async (): Promise<void> => {
  await run({
    changelogPath: core.getInput('changelog_path', { required: true }),
  })
}

main().catch((e: Error) => {
  core.setFailed(e)
  console.error(e)
})
