import { run } from '../src/run.js'

test('run successfully', async () => {
  await expect(run({ releaseType: 'patch' })).resolves.toBeUndefined()
})
