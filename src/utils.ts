import exec from '@actions/exec'

export const easyExec = async function easyExec(commandWithArgs: string) {
  let output = ''
  let error = ''

  const options = {
    listeners: {
      stdout: (data: any) => {
        output += data.toString()
      },
      stderr: (data: any) => {
        error += data.toString()
      },
    },
    silent: true,
  }

  const commandParts = commandWithArgs.split(' ')
  const command = commandParts[0]
  const args = commandParts.slice(1)

  console.log(`${command} ${args.join(' ')}`)

  let exitCode
  try {
    exitCode = await exec.exec(command, args, options)
  } catch (e) {
    return { output, error, exitCode: 2 }
  }

  if (exitCode !== 0) {
    throw new Error(`"${command}" returned an exit code of ${exitCode}`)
  }

  return {
    output,
    error,
    exitCode,
  }
}

export const setOutput = function setOutput(key: string, value: any) {
  exec.exec(`echo "${key}=${value}" >> $GITHUB_OUTPUT`)
}
