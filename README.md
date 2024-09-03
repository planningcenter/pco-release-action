# 🚀 PCO-Release

## Summary

PCO-Release helps to manage the process of releasing our JavaScript/TypeScript libraries.
It creates PRs when changes are merged into `main` and help to streamline the process
for getting the release pushed out. It does this via Github Actions.

## Quickstart

Because there are multiple triggers for `PCO-Release` to work, multiple actions are required.

#### Create a Release PR when content gets added to the `main` branch

```yml
# .github/workflows/pco-release-create-pr.yml

on:
  push:
    branches:
      - main

permissions:
  contents: write
  pull-requests: write

name: PCO-Release - Release Automation

jobs:
  release-automation:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: "yarn"
      - uses: planningcenter/pco-release-action/release-by-pr@v1
        with:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

#### Sync the version bump type via labels on the Release PR

```yml
# .github/workflows/pco-release-sync-release-by-label.yml

on:
  pull_request:
    types: [labeled]

permissions:
  contents: write
  pull-requests: write

name: PCO-Release - Sync With Labels

jobs:
  sync-with-labels:
    if: ${{ github.event.pull_request.head.ref == 'pco-release--internal' && (github.event.label.name == 'pco-release-patch' || github.event.label.name == 'pco-release-minor' || github.event.label.name == 'pco-release-major') }}
    runs-on: ubuntu-latest
    steps:
      - uses: planningcenter/pco-release-action/sync-with-labels@v1
        with:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

#### Automatically creates a Github Release when

```yml
# .github/workflows/pco-release-create-release-on-merge.yml

name: PCO-Release - Create Release on Merge

on:
  pull_request:
    types: [closed]
    branches:
      - main

jobs:
  create-release:
    runs-on: ubuntu-latest
    if: github.event.pull_request.merged == true && contains(github.event.pull_request.labels.*.name, 'pco-release-pending')
    steps:
      - uses: planningcenter/pco-release-action/create-release-on-merge@v1
```

#### Require the CHANGELOG.md file to be updated in general PRs (to use human communication about changes)

```yml
# .github/workflows/pco-release-require-changelog-update.yml

name: PCO-Release - Require Changelog Update

on:
  pull_request:
    branches: [main]

jobs:
  require-changelog-update:
    runs-on: ubuntu-latest
    permissions:
      pull-requests: read
      contents: read
    steps:
      - uses: actions/checkout@v4
      - id: changed-files
        uses: tj-actions/changed-files@v44
        with:
          files: CHANGELOG.md
      - if: steps.changed-files.outputs.any_changed == 'false'
        run: |
          echo "Pull Requests require an update to the CHANGELOG.md file."
          exit 1
```

#### Automate updating the Changelog when dependabot opens a PR

```yml
# .github/workflows/pco-release-dependabot-automation.yml

name: PCO-Release - Dependabot Automation (Update changelog)

on: pull_request

jobs:
  update-dependabot-pr-changelog:
    if: github.actor == 'dependabot[bot]'
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.event.pull_request.head.ref }}
      - uses: planningcenter/pco-release-action/dependabot-automation@v1
```

#### Automate the creation of Release candidate releases

See [create-prerelease-candidate](./create-release-candidate/README.md)

#### Automate the creation of QA releases

See [create-qa-release](./create-qa-release/README.md)

#### Set up Auto Deploys

See the [`deploy` action readme](./deploy/README.md).

## Available workflows

### Release

This will be available to create a new release and deploy it to all consumers via PR.

#### Configuration variables

You can customize the commands the workflow runs for installing dependencies, building, and testing the package.
If no options are provided, the defaults will be used.

| Input              | Description                                                                                                                                        | Req'd | Default                      |
| ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------- | ----- | ---------------------------- |
| `build-command`    | The command to run to build the package                                                                                                            | No    | `yarn build`                 |
| `build-directory`  | The directory containing the build output                                                                                                          | No    | `dist`                       |
| `cache`            | Used to specify a package manager for caching in the default directory. Supported values: npm, yarn, pnpm, or '' for no caching.                   | No    | `yarn`                       |
| `install-command`  | The command to run to install the package's dependencies                                                                                           | No    | `yarn install --check-files` |
| `publish-command`  | The command to publish a release version of the package to NPM                                                                                     | No    | `npm publish`                |
| `test-command`     | The command to run to test the package                                                                                                             | No    | `yarn test`                  |
| `only`             | A comma separated list of repos that will only be updated                                                                                          | No    | ''                           |
| `include`          | A comma separated list of repos to include without checking for the dependency.                                                                    | No    | ''                           |
| `exclude`          | A comma separated list of repos to exclude without checking for the dependency.                                                                    | No    | ''                           |
| `upgrade-commands` | "JSON string of repo names and their specific upgrade commands. Useful for monorepos where the package.json does not exist in the root directory." | No    | `"{}"`                       |

#### Usage

Create a workflow within your own JavaScript library. As an example, in `.github/workflows/rc.yml`...

```yml
on:
  pull_request:
    types: [closed]
    branches:
      - main

jobs:
  create-release:
    if: github.event.pull_request.merged == true && contains(github.event.pull_request.labels.*.name, 'pco-release-pending')
    permissions:
      contents: write
      pull-requests: write
      packages: write
    uses: planningcenter/pco-release-action/create-release-on-merge@v1
    secrets: inherit
```

### release candidate (rc)

This will be available to create a release candidate from a release PR, publish it, and send it to staging for all consumers.

#### Configuration variables

You can customize the commands the workflow runs for installing dependencies, building, and testing the package.
If no options are provided, the defaults will be used.

| Input                | Description                                                                                                                                        | Req'd | Default                      |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- | ----- | ---------------------------- |
| `build-command`      | The command to run to build the package                                                                                                            | No    | `yarn build`                 |
| `build-directory`    | The directory containing the build output                                                                                                          | No    | `dist`                       |
| `cache`              | Used to specify a package manager for caching in the default directory. Supported values: npm, yarn, pnpm, or '' for no caching.                   | No    | `yarn`                       |
| `install-command`    | The command to run to install the package's dependencies                                                                                           | No    | `yarn install --check-files` |
| `prepublish-command` | The command to publish a prerelease version of the package to NPM                                                                                  | No    | `npm publish --tag next`     |
| `test-command`       | The command to run to test the package                                                                                                             | No    | `yarn test`                  |
| `only`               | A comma separated list of repos that will only be updated                                                                                          | No    | ''                           |
| `include`            | A comma separated list of repos to include without checking for the dependency.                                                                    | No    | ''                           |
| `exclude`            | A comma separated list of repos to exclude without checking for the dependency.                                                                    | No    | ''                           |
| `upgrade-commands`   | "JSON string of repo names and their specific upgrade commands. Useful for monorepos where the package.json does not exist in the root directory." | No    | `"{}"`                       |

#### Usage

Create a workflow within your own JavaScript library. As an example, in `.github/workflows/rc.yml`...

```yml
on:
  issue_comment:
    types: [created]

jobs:
  create-rc-and-deploy:
    if: (github.event_name == 'workflow_dispatch') || (github.event.issue.pull_request && contains(github.event.comment.body, '@pco-release rc'))
    permissions:
      contents: write
      pull-requests: write
      packages: write
    uses: planningcenter/pco-release-action/.github/workflows/rc.yml@v1
    secrets: inherit
```

### QA Release

This will be available to create a QA release from a PR for testing a specific branch, publish it, and send it to a protonova environment for all consumers.

#### Configuration variables

You can customize the commands the workflow runs for installing dependencies, building, and testing the package.
If no options are provided, the defaults will be used.

| Input                | Description                                                                                                                                        | Req'd | Default                      |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- | ----- | ---------------------------- |
| `build-command`      | The command to run to build the package                                                                                                            | No    | `yarn build`                 |
| `build-directory`    | The directory containing the build output                                                                                                          | No    | `dist`                       |
| `cache`              | Used to specify a package manager for caching in the default directory. Supported values: npm, yarn, pnpm, or '' for no caching.                   | No    | `yarn`                       |
| `install-command`    | The command to run to install the package's dependencies                                                                                           | No    | `yarn install --check-files` |
| `prepublish-command` | The command to publish a prerelease version of the package to NPM                                                                                  | No    | `npm publish --tag next`     |
| `test-command`       | The command to run to test the package                                                                                                             | No    | `yarn test`                  |
| `only`               | A comma separated list of repos that will only be updated                                                                                          | No    | ''                           |
| `include`            | A comma separated list of repos to include without checking for the dependency.                                                                    | No    | ''                           |
| `exclude`            | A comma separated list of repos to exclude without checking for the dependency.                                                                    | No    | ''                           |
| `upgrade-commands`   | "JSON string of repo names and their specific upgrade commands. Useful for monorepos where the package.json does not exist in the root directory." | No    | `"{}"`                       |

#### Usage

Create a workflow within your own JavaScript library. As an example, in `.github/workflows/qa.yml`...

```yml
on:
  issue_comment:
    types: [created]

jobs:
  create-qa-release-and-deploy:
    if: (github.event_name == 'workflow_dispatch') || (github.event.issue.pull_request && contains(github.event.comment.body, '@pco-release qa'))
    permissions:
      contents: write
      pull-requests: write
      packages: write
    uses: planningcenter/pco-release-action/.github/workflows/qa-release.yml@v1
    secrets: inherit
```

## Working on this Project

- Build before pushing changes with `yarn build`
