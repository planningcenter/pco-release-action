# Create Release Candidate Github Action

## Summary

This action helps to automate the process of creating a pre-release build of a release PR. It works
best when setting up a listener on a comment of a PR like `@pco-release rc`.

## Usage

Add a workflow file to listen on a `@pco-release rc` comment.

```yml
name: Create RC Prerelease
on:
  issue_comment:
    types: [created]

jobs:
  auto-deploy-after-release:
    if: github.event.issue.pull_request && contains(github.event.comment.body, '@pco-release rc')
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
    steps:
      - uses: planningcenter/pco-release-action/create-release-candidate@v1
        with:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          ##############################
          # the following are optional #
          ##############################
          # node-version: 20
          # package-json-path: 'package.json'
          # yarn-version-command: 'yarn version'
```

Then in Release PRs, you can comment with something like this:

```
@pco-release rc

This Release Candidate is testing out the Widget feature.

It is important to test:

- Thing A
- Thing B
```

This comment will add all the extra text in the comment to the release information.
