import { run } from '../src/run.js'

test('run successfully', async () => {
  await expect(
    run({ releaseType: 'patch', versionCommand: 'yarn version', packageJsonPath: 'package.json' }),
  ).resolves.toBeUndefined()
})
