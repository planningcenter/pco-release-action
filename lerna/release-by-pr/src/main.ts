import * as core from '@actions/core'
import { run } from './run.js'

const main = async (): Promise<void> => {
  await run({
    releaseType: core.getInput('release-type', { required: false }) as 'patch' | 'minor' | 'major' | undefined,
    installCommand: core.getInput('install-command', { required: false }),
  })
}

main().catch((e: Error) => {
  core.setFailed(e)
  console.error(e)
})
