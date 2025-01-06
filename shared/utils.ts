import { exec } from '@actions/exec'
import fs from 'fs'

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
    cwd: process.env.GITHUB_WORKSPACE,
  }

  const commandParts = commandWithArgs.match(/(?:[^\s'"]+|"[^"]*"|'[^']*')+/g)
  if (commandParts === null) throw new Error('Command parts are null')
  const command = commandParts[0]
  const args = commandParts.slice(1).map((arg) => {
    if ((arg.startsWith('"') && arg.endsWith('"')) || (arg.startsWith("'") && arg.endsWith("'"))) {
      return arg.slice(1, -1)
    }
    return arg
  })

  console.log(`${command} ${args.join(' ')}`)

  let exitCode
  try {
    exitCode = await exec(command, args, options)
  } catch (e) {
    console.log({ output, error, exitCode: 2, e })
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
  exec(`echo "${key}=${value}" >> $GITHUB_OUTPUT`)
}

export async function replaceTextInFile(filePath: string, searchText: string, replacementText: string): Promise<void> {
  // Don't do anything if the search text is empty
  if (!searchText) {
    return
  }

  const fileContent = await readFileContent(filePath)
  const updatedContent = fileContent.replace(searchText, replacementText)
  await saveFileContent(filePath, updatedContent)
}

export async function readFileContent(filePath: string): Promise<string> {
  try {
    const fileContentBuffer = await fs.promises.readFile(filePath, 'utf8')
    return fileContentBuffer.toString()
  } catch (error) {
    throw new Error(`Error reading file content: ${error}`)
  }
}

export async function saveFileContent(filePath: string, content: string): Promise<void> {
  try {
    await fs.promises.writeFile(filePath, content)
  } catch (error) {
    throw new Error(`Error saving file content: ${error}`)
  }
}
