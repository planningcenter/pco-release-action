# Create QA Release Github Action

## Summary

This action helps to automate the process of creating a QA release for testing a PR. It works
by listening for the comment `@pco-release qa`.

## Usage

Add a workflow file to listen on a `@pco-release qa` comment.

```yml
name: Create QA Prerelease
on:
  issue_comment:
    types: [created]

jobs:
  auto-deploy-after-release:
    if: github.event.issue.pull_request && contains(github.event.comment.body, '@pco-release qa')
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
    steps:
      - uses: planningcenter/pco-release-action/create-qa-release@v1
        with:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          ##############################
          # the following are optional #
          ##############################
          # node-version: 20
          # package-json-path: 'package.json'
          # yarn-version-command: 'yarn version'
```

Then in your PRs, you can comment with something like this:

```
@pco-release qa
This Release Candidate is testing out the Widget feature.
It is important to test:
- Thing A
- Thing B
```

This comment will add all the extra text in the comment to the release information.
