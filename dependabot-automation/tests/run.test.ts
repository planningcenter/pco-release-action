import { updateChangelog } from '../src/run.js'

function removeIndentation(str: string) {
  return str.replace(/^[ \t]+/gm, '')
}

describe('updateChangelog', () => {
  it('adds dependencies and the message in the current release', () => {
    const changelog = removeIndentation(
      `# Changelog

      ## Unreleased

      ## v2.1.4

      ### Dependencies

      - chore: update dependencies`,
    )
    const expectedResult = expect(updateChangelog({ changelog, message: `fix: something` })).toEqual(
      removeIndentation(
        `# Changelog

        ## Unreleased

        ### Dependencies

        - fix: something

        ## v2.1.4

        ### Dependencies

        - chore: update dependencies`,
      ),
    )
  })

  it('appends to the list of dependencies when it already exists', () => {
    const changelog = removeIndentation(`# Changelog

      ## Unreleased

      ### Dependencies

      - some other thing

      ## v2.1.4

      ### Dependencies

      - chore: update dependencies`)
    expect(updateChangelog({ changelog, message: `fix: something` })).toEqual(
      removeIndentation(
        `# Changelog

        ## Unreleased

        ### Dependencies

        - some other thing
        - fix: something

        ## v2.1.4

        ### Dependencies

        - chore: update dependencies`,
      ),
    )
  })

  it('adds dependencies when another h3 exists', () => {
    const changelog = removeIndentation(
      `# Changelog

      ## Unreleased

      ### Fixed

      - Did a thing

      ## v2.1.4

      ### Dependencies

      - chore: update dependencies`,
    )
    expect(updateChangelog({ changelog, message: `fix: something` })).toEqual(
      removeIndentation(
        `# Changelog

        ## Unreleased

        ### Fixed

        - Did a thing

        ### Dependencies

        - fix: something

        ## v2.1.4

        ### Dependencies

        - chore: update dependencies`,
      ),
    )
  })

  it('adds dependencies when it is before other h3s', () => {
    const changelog = removeIndentation(
      `# Changelog

      ## Unreleased

      ### Added

      - did a thing

      ### Dependencies

      - updated a dep

      ### Fixed

      - fixed a thing

      ## v2.1.4

      ### Dependencies

      - chore: update dependencies`,
    )
    expect(updateChangelog({ changelog, message: `fix: something` })).toEqual(
      removeIndentation(
        `# Changelog

        ## Unreleased

        ### Added

        - did a thing

        ### Dependencies

        - updated a dep
        - fix: something

        ### Fixed

        - fixed a thing

        ## v2.1.4

        ### Dependencies

        - chore: update dependencies`,
      ),
    )
  })
})
