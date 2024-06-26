import * as core from '@actions/core'
import { run } from './run.js'

const main = async (): Promise<void> => {
  await run({
    releaseType: core.getInput('release_type', { required: true }) as 'patch' | 'minor' | 'major' | 'nochange',
    packageJsonPath: core.getInput('package_json_path', { required: true }),
    versionCommand: core.getInput('version_command', { required: true }),
  })
}

main().catch((e: Error) => {
  core.setFailed(e)
  console.error(e)
})
