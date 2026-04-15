# PCO-Release

PCO-Release automates the release process for Planning Center's JavaScript/TypeScript libraries. It manages version bumping, changelog updates, PR creation, npm publishing, and coordinated deployments across consuming repositories -- all via GitHub Actions.

## Table of Contents

- [How It Works](#how-it-works)
- [Standard Repos](#standard-repos)
  - [Quick Setup](#quick-setup)
  - [Release (create, publish, deploy)](#release)
  - [Release Candidate (RC)](#release-candidate-rc)
  - [QA Release](#qa-release)
  - [Revert](#revert)
- [Lerna Monorepos](#lerna-monorepos)
  - [Quick Setup (Lerna)](#quick-setup-lerna)
  - [Release on Merge (Lerna)](#release-on-merge-lerna)
  - [QA Release (Lerna)](#qa-release-lerna)
  - [Deploy RC (Lerna)](#deploy-rc-lerna)
- [Shared Workflows](#shared-workflows)
  - [Sync Version via Labels](#sync-version-via-labels)
  - [Require Changelog Updates](#require-changelog-updates)
  - [Dependabot Changelog Automation](#dependabot-changelog-automation)
- [Actions Reference](#actions-reference)
- [NPM Authentication via OIDC Trusted Publishing](#npm-authentication-via-oidc-trusted-publishing)
- [Configuration Reference](#configuration-reference)
- [Contributing](#contributing)

---

## How It Works

The typical release flow for a library using PCO-Release:

1. **Developer merges a PR to `main`** -- the `release-by-pr` action creates a release PR on the `pco-release--internal` branch with a version bump and changelog update.
2. **Labels control the version bump** -- apply `pco-release-patch`, `pco-release-minor`, or `pco-release-major` to the release PR. The `sync-with-labels` action updates the version accordingly.
3. **Release PR is merged** -- the release workflow publishes to npm and creates a GitHub release.
4. **Deploy** -- the `deploy` action opens PRs to update the dependency across all consuming repos.

At any point during development, you can also create [Release Candidates](#release-candidate-rc) or [QA Releases](#qa-release) by commenting on PRs.

---

## Standard Repos

For single-package JavaScript/TypeScript libraries. Add these workflow files to your library's `.github/workflows/` directory.

Ensure your repo has access to the `PCO_DEPENDENCIES_APP_ID` and `PCO_DEPENDENCIES_PRIVATE_KEY` secrets (reach out in **#github-discuss** on Slack if you need access).

### Quick Setup

To get the full release automation working, you need these workflow files at minimum:

**1. Create a release PR when code is merged to `main`**

```yml
# .github/workflows/pco-release-create-pr.yml
on:
  push:
    branches:
      - main

permissions:
  contents: write
  pull-requests: write

name: PCO-Release - Create Release PR

jobs:
  release-automation:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "24"
          cache: "yarn"
      - uses: planningcenter/pco-release-action/release-by-pr@v1
        with:
          app-id: ${{ secrets.PCO_DEPENDENCIES_APP_ID }}
          private-key: ${{ secrets.PCO_DEPENDENCIES_PRIVATE_KEY }}
```

**2. Publish and deploy when the release PR is merged**

```yml
# .github/workflows/pco-release-on-merge.yml
on:
  pull_request:
    types: [closed]
    branches:
      - main

name: PCO-Release - Release on Merge

jobs:
  release:
    if: >-
      github.event.pull_request.merged == true &&
      contains(github.event.pull_request.labels.*.name, 'pco-release-pending')
    permissions:
      contents: write
      pull-requests: write
      packages: write
      id-token: write  # Required for OIDC trusted publishing
    uses: planningcenter/pco-release-action/.github/workflows/release.yml@v1
    secrets: inherit
    with:
      pr-number: ${{ github.event.pull_request.number }}
```

You'll also want to add the [shared workflows](#shared-workflows) (label syncing, changelog enforcement, and dependabot automation).

### Release

**Workflow:** `planningcenter/pco-release-action/.github/workflows/release.yml@v1`

Creates a GitHub release, publishes to npm and GitHub Package Registry, and deploys to all consuming repos via PRs. This is the main workflow for publishing a release.

**Trigger:** When a release PR (with `pco-release-pending` label) is merged to `main`.

> **Requires [OIDC trusted publishing](#npm-authentication-via-oidc-trusted-publishing)** -- your package must be configured on npmjs.com and the calling workflow must include `id-token: write`.

```yml
# .github/workflows/pco-release-on-merge.yml
on:
  pull_request:
    types: [closed]
    branches:
      - main

jobs:
  release:
    if: >-
      github.event.pull_request.merged == true &&
      contains(github.event.pull_request.labels.*.name, 'pco-release-pending')
    permissions:
      contents: write
      pull-requests: write
      packages: write
      id-token: write  # Required for OIDC trusted publishing
    uses: planningcenter/pco-release-action/.github/workflows/release.yml@v1
    secrets: inherit
    with:
      pr-number: ${{ github.event.pull_request.number }}
      # All below are optional:
      # install-command: yarn install --check-files
      # build-command: yarn build
      # test-command: yarn test
      # publish-command: npm publish
      # cache: yarn
      # build-directory: dist
      # only: ""
      # include: ""
      # exclude: ""
      # upgrade-commands: "{}"
      # package-json-path: package.json
```

| Input | Description | Default |
|---|---|---|
| `pr-number` | **(required)** The PR number that triggered the release | |
| `install-command` | Command to install dependencies | `yarn install --check-files` |
| `build-command` | Command to build the package | `yarn build` |
| `test-command` | Command to run tests | `yarn test` |
| `publish-command` | Command to publish to npm | `npm publish` |
| `cache` | Package manager for caching (`npm`, `yarn`, `pnpm`, or `""`) | `yarn` |
| `build-directory` | Directory containing build output | `dist` |
| `only` | Comma-separated list of repos to exclusively update | `""` |
| `include` | Comma-separated list of repos to include (without checking for dep) | `""` |
| `exclude` | Comma-separated list of repos to exclude | `""` |
| `upgrade-commands` | JSON string of repo-specific upgrade commands | `"{}"` |
| `package-json-path` | Path to package.json | `package.json` |

---

### Release Candidate (RC)

**Workflow:** `planningcenter/pco-release-action/.github/workflows/release-candidate.yml@v1`

Creates an RC prerelease version, publishes to npm with the `@next` tag, and merges to the staging branch in consumer repos.

**Trigger:** Comment `@pco-release rc` on a release PR.

> **Requires [OIDC trusted publishing](#npm-authentication-via-oidc-trusted-publishing)** -- your package must be configured on npmjs.com and the calling workflow must include `id-token: write`.

```yml
# .github/workflows/pco-release-rc.yml
on:
  issue_comment:
    types: [created]

jobs:
  create-rc-and-deploy:
    if: >-
      github.event.issue.pull_request &&
      contains(github.event.comment.body, '@pco-release rc')
    permissions:
      contents: write
      pull-requests: write
      packages: write
      id-token: write  # Required for OIDC trusted publishing
    uses: planningcenter/pco-release-action/.github/workflows/release-candidate.yml@v1
    secrets: inherit
```

You can include additional context in the comment that will be added to the release notes:

```
@pco-release rc

This RC is testing the new Widget feature.

Please test:
- Thing A
- Thing B
```

| Input | Description | Default |
|---|---|---|
| `install-command` | Command to install dependencies | `yarn install --check-files` |
| `build-command` | Command to build the package | `yarn build` |
| `test-command` | Command to run tests | `yarn test` |
| `prepublish-command` | Command to publish the prerelease to npm | `npm publish --tag next` |
| `cache` | Package manager for caching | `yarn` |
| `build-directory` | Directory containing build output | `dist` |
| `only` | Comma-separated list of repos to exclusively update | `""` |
| `include` | Comma-separated list of repos to include | `""` |
| `exclude` | Comma-separated list of repos to exclude | `""` |
| `upgrade-commands` | JSON string of repo-specific upgrade commands | `"{}"` |
| `package-json-path` | Path to package.json | `package.json` |
| `yarn-version-command` | Command to bump version | `yarn version` |

---

### QA Release

**Workflow:** `planningcenter/pco-release-action/.github/workflows/qa-release.yml@v1`

Creates a QA prerelease version for testing a specific branch, publishes to npm, and deploys to a protonova environment.

**Trigger:** Comment `@pco-release qa` on any PR.

> **Requires [OIDC trusted publishing](#npm-authentication-via-oidc-trusted-publishing)** -- your package must be configured on npmjs.com and the calling workflow must include `id-token: write`.

```yml
# .github/workflows/pco-release-qa.yml
on:
  issue_comment:
    types: [created]

jobs:
  create-qa-release-and-deploy:
    if: >-
      github.event.issue.pull_request &&
      contains(github.event.comment.body, '@pco-release qa')
    permissions:
      contents: write
      pull-requests: write
      packages: write
      id-token: write  # Required for OIDC trusted publishing
    uses: planningcenter/pco-release-action/.github/workflows/qa-release.yml@v1
    secrets: inherit
```

You can include test instructions in the comment:

```
@pco-release qa

Testing the new Widget feature in protonova.
```

| Input | Description | Default |
|---|---|---|
| `install-command` | Command to install dependencies | `yarn install --check-files` |
| `build-command` | Command to build the package | `yarn build` |
| `test-command` | Command to run tests | `yarn test` |
| `prepublish-command` | Command to publish the prerelease to npm | `npm publish --tag next` |
| `cache` | Package manager for caching | `yarn` |
| `build-directory` | Directory containing build output | `dist` |
| `only` | Comma-separated list of repos to exclusively update | `""` |
| `include` | Comma-separated list of repos to include | `""` |
| `exclude` | Comma-separated list of repos to exclude | `""` |
| `upgrade-commands` | JSON string of repo-specific upgrade commands | `"{}"` |
| `package-json-path` | Path to package.json | `package.json` |
| `yarn-version-command` | Command to bump version | `yarn version` |
| `branch-name` | Custom proto deploy branch name | |
| `custom-message` | Custom message for the deployment report | |

---

### Revert

**Workflow:** `planningcenter/pco-release-action/.github/workflows/revert.yml@v1`

Quickly reverts all consumer repos to a previous version of the library by creating PRs.

**Trigger:** Manual workflow dispatch.

```yml
# .github/workflows/pco-release-revert.yml
on:
  workflow_dispatch:
    inputs:
      pr-number:
        description: "PR number to comment the report to"
        required: true
      release-tag:
        description: "Release tag to revert to (e.g. v4.9.1)"
        required: true

jobs:
  revert:
    permissions:
      contents: write
      pull-requests: write
    uses: planningcenter/pco-release-action/.github/workflows/revert.yml@v1
    secrets: inherit
    with:
      pr-number: ${{ inputs.pr-number }}
      release-tag: ${{ inputs.release-tag }}
```

| Input | Description | Default |
|---|---|---|
| `pr-number` | **(required)** PR number to post the revert report to | |
| `release-tag` | **(required)** The release tag to revert to (e.g. `v4.9.1`) | |
| `only` | Comma-separated list of repos to exclusively update | `""` |
| `include` | Comma-separated list of repos to include | `""` |
| `exclude` | Comma-separated list of repos to exclude | `""` |
| `package-json-path` | Path to package.json | `package.json` |

---

## Lerna Monorepos

For Lerna monorepos where multiple packages need coordinated version bumps. Use these workflows instead of the standard ones above.

Ensure your repo has access to the `PCO_DEPENDENCIES_APP_ID` and `PCO_DEPENDENCIES_PRIVATE_KEY` secrets (reach out in **#github-discuss** on Slack if you need access).

### Quick Setup (Lerna)

**1. Create a release PR when code is merged to `main`**

```yml
# .github/workflows/pco-release-create-pr.yml
on:
  push:
    branches:
      - main

jobs:
  release-pr:
    permissions:
      contents: write
      pull-requests: write
      packages: write
      id-token: write  # Required for OIDC trusted publishing
    uses: planningcenter/pco-release-action/.github/workflows/lerna-release-pr.yml@v1
    secrets: inherit
```

**2. Publish and deploy when the release PR is merged**

```yml
# .github/workflows/pco-release-on-merge.yml
on:
  pull_request:
    types: [closed]
    branches:
      - main

jobs:
  release:
    if: >-
      github.event.pull_request.merged == true &&
      contains(github.event.pull_request.labels.*.name, 'pco-release-pending')
    permissions:
      contents: write
      pull-requests: write
      packages: write
      id-token: write  # Required for OIDC trusted publishing
    uses: planningcenter/pco-release-action/.github/workflows/lerna-release-on-merge.yml@v1
    secrets: inherit
```

You'll also want to add the [shared workflows](#shared-workflows) (label syncing, changelog enforcement, and dependabot automation).

### Create Release PR (Lerna)

**Workflow:** `planningcenter/pco-release-action/.github/workflows/lerna-release-pr.yml@v1`

Creates a release PR and publishes RC versions for changed packages when code is pushed to `main`.

> **Requires [OIDC trusted publishing](#npm-authentication-via-oidc-trusted-publishing)** -- your packages must be configured on npmjs.com and the calling workflow must include `id-token: write`.

```yml
# .github/workflows/pco-release-create-pr.yml
on:
  push:
    branches:
      - main

jobs:
  release-pr:
    permissions:
      contents: write
      pull-requests: write
      packages: write
      id-token: write  # Required for OIDC trusted publishing
    uses: planningcenter/pco-release-action/.github/workflows/lerna-release-pr.yml@v1
    secrets: inherit
```

| Input | Description | Default |
|---|---|---|
| `install-command` | Command to install dependencies | `yarn install --check-files` |
| `node-version` | Node.js version | `24` |
| `cache` | Package manager for caching | `yarn` |

### Release on Merge (Lerna)

**Workflow:** `planningcenter/pco-release-action/.github/workflows/lerna-release-on-merge.yml@v1`

Publishes all packages and deploys to consumers when the Lerna release PR is merged.

> **Requires [OIDC trusted publishing](#npm-authentication-via-oidc-trusted-publishing)** -- your packages must be configured on npmjs.com and the calling workflow must include `id-token: write`.

```yml
# .github/workflows/pco-release-on-merge.yml
on:
  pull_request:
    types: [closed]
    branches:
      - main

jobs:
  release:
    if: >-
      github.event.pull_request.merged == true &&
      contains(github.event.pull_request.labels.*.name, 'pco-release-pending')
    permissions:
      contents: write
      pull-requests: write
      packages: write
      id-token: write  # Required for OIDC trusted publishing
    uses: planningcenter/pco-release-action/.github/workflows/lerna-release-on-merge.yml@v1
    secrets: inherit
```

| Input | Description | Default |
|---|---|---|
| `install-command` | Command to install dependencies | `yarn install --check-files` |
| `node-version` | Node.js version | `24` |
| `cache` | Package manager for caching | `yarn` |
| `only` | Comma-separated list of repos to exclusively update | `""` |
| `include` | Comma-separated list of repos to include | `""` |
| `exclude` | Comma-separated list of repos to exclude | `""` |

### QA Release (Lerna)

**Workflow:** `planningcenter/pco-release-action/.github/workflows/lerna-qa-release.yml@v1`

Creates QA releases for all changed packages in the monorepo. Triggered by commenting `@pco-release qa` on a PR.

> **Supports [OIDC trusted publishing](#npm-authentication-via-oidc-trusted-publishing)** -- set `use-oidc: true` and add `id-token: write` to your calling workflow permissions. OIDC will become the default in a future release.

```yml
# .github/workflows/pco-release-qa.yml
on:
  issue_comment:
    types: [created]

jobs:
  create-qa-release-and-deploy:
    if: >-
      github.event.issue.pull_request &&
      contains(github.event.comment.body, '@pco-release qa')
    permissions:
      contents: write
      pull-requests: write
      packages: write
      id-token: write  # Required when use-oidc is true
    uses: planningcenter/pco-release-action/.github/workflows/lerna-qa-release.yml@v1
    secrets: inherit
    with:
      use-oidc: true
```

| Input | Description | Default |
|---|---|---|
| `install-command` | Command to install dependencies | `yarn install --check-files` |
| `node-version` | Node.js version | `24` |
| `cache` | Package manager for caching | `yarn` |
| `only` | Comma-separated list of repos to exclusively update | `""` |
| `include` | Comma-separated list of repos to include | `""` |
| `exclude` | Comma-separated list of repos to exclude | `""` |
| `lerna-json-path` | Path to lerna.json | `lerna.json` |
| `branch-name` | Custom proto deploy branch name | |
| `custom-message` | Custom deployment message | |
| `use-oidc` | Use OIDC trusted publishing instead of `PLANNINGCENTER_NPM_TOKEN` | `false` |

### Deploy RC (Lerna)

**Workflow:** `planningcenter/pco-release-action/.github/workflows/lerna-deploy-rc.yml@v1`

Deploys RC versions to staging for consumer repos. Triggered by commenting `@pco-release deploy` on the release PR.

```yml
# .github/workflows/pco-release-deploy-rc.yml
on:
  issue_comment:
    types: [created]

jobs:
  deploy-rc:
    if: >-
      github.event.issue.pull_request &&
      contains(github.event.comment.body, '@pco-release deploy')
    permissions:
      contents: write
      pull-requests: write
    uses: planningcenter/pco-release-action/.github/workflows/lerna-deploy-rc.yml@v1
    secrets: inherit
```

| Input | Description | Default |
|---|---|---|
| `install-command` | Command to install dependencies | `yarn install --check-files` |
| `node-version` | Node.js version | `24` |
| `cache` | Package manager for caching | `yarn` |
| `only` | Comma-separated list of repos to exclusively update | `""` |
| `include` | Comma-separated list of repos to include | `""` |
| `exclude` | Comma-separated list of repos to exclude | `""` |
| `upgrade-commands` | JSON string of repo-specific upgrade commands | `"{}"` |

---

## Shared Workflows

These workflows work the same way for both standard repos and Lerna monorepos.

### Sync Version via Labels

Keeps the release PR version in sync when `pco-release-patch`, `pco-release-minor`, or `pco-release-major` labels are added.

```yml
# .github/workflows/pco-release-sync-with-labels.yml
on:
  pull_request:
    types: [labeled]

permissions:
  contents: write
  pull-requests: write

name: PCO-Release - Sync With Labels

jobs:
  sync-with-labels:
    if: >-
      github.event.pull_request.head.ref == 'pco-release--internal' &&
      (github.event.label.name == 'pco-release-patch' ||
       github.event.label.name == 'pco-release-minor' ||
       github.event.label.name == 'pco-release-major')
    runs-on: ubuntu-latest
    steps:
      - uses: planningcenter/pco-release-action/sync-with-labels@v1
        with:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Require Changelog Updates

Enforces that PRs to `main` include a CHANGELOG.md update.

```yml
# .github/workflows/pco-release-require-changelog.yml
on:
  pull_request:
    branches: [main]

name: PCO-Release - Require Changelog Update

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

### Dependabot Changelog Automation

Automatically adds changelog entries when dependabot creates PRs, so they pass the changelog requirement.

```yml
# .github/workflows/pco-release-dependabot-automation.yml
on: pull_request

name: PCO-Release - Dependabot Automation

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

---

## Actions Reference

Individual composite actions used by the workflows above. You can also use them directly in workflow steps for custom setups.

### release-by-pr

Creates or updates a release PR on the `pco-release--internal` branch with version bumps based on conventional commits.

```yml
- uses: planningcenter/pco-release-action/release-by-pr@v1
  with:
    app-id: ${{ secrets.PCO_DEPENDENCIES_APP_ID }}
    private-key: ${{ secrets.PCO_DEPENDENCIES_PRIVATE_KEY }}
```

| Input | Description | Default |
|---|---|---|
| `app-id` | GitHub App ID for authentication | |
| `private-key` | GitHub App private key | |
| `GITHUB_TOKEN` | Alternative: GitHub token | |
| `release_type` | Force a release type (`patch`, `minor`, `major`, `nochange`) | `nochange` |
| `package_json_path` | Path to package.json | `package.json` |
| `version_command` | Command to bump version | `yarn version` |

### create-release-on-merge

Creates a GitHub release when a release PR is merged.

```yml
- uses: planningcenter/pco-release-action/create-release-on-merge@v1
  with:
    app-id: ${{ secrets.PCO_DEPENDENCIES_APP_ID }}
    private-key: ${{ secrets.PCO_DEPENDENCIES_PRIVATE_KEY }}
```

| Input | Description | Default |
|---|---|---|
| `app-id` | GitHub App ID (allows triggering other workflows) | |
| `private-key` | GitHub App private key | |
| `package_json_path` | Path to package.json | `package.json` |

### sync-with-labels

Updates the version bump type on a release PR when `pco-release-patch`, `pco-release-minor`, or `pco-release-major` labels are applied.

```yml
- uses: planningcenter/pco-release-action/sync-with-labels@v1
  with:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

| Input | Description | Default |
|---|---|---|
| `GITHUB_TOKEN` | **(required)** GitHub token | |
| `cache` | Package manager for caching | `yarn` |
| `package_json_path` | Path to package.json | `package.json` |
| `version_command` | Command to bump version | `yarn version` |

### dependabot-automation

Automatically adds changelog entries when dependabot creates PRs.

```yml
- uses: planningcenter/pco-release-action/dependabot-automation@v1
```

| Input | Description | Default |
|---|---|---|
| `changelog_path` | Path to the changelog file | `./CHANGELOG.md` |

### deploy

Creates PRs (or merges directly) to update a package version across all consumer repositories.

```yml
- uses: planningcenter/pco-release-action/deploy@v1
  with:
    app-id: ${{ secrets.PCO_DEPENDENCIES_APP_ID }}
    private-key: ${{ secrets.PCO_DEPENDENCIES_PRIVATE_KEY }}
```

| Input | Description | Default |
|---|---|---|
| `app-id` | **(required)** GitHub App ID | |
| `private-key` | **(required)** GitHub App private key | |
| `automerge` | Auto-merge PRs for compatible versions | |
| `change-method` | How to apply changes: `pr`, `merge`, or `revert` | `pr` |
| `branch-name` | Target branch for `merge` method | `staging` |
| `only` | Comma-separated repos to exclusively update | `""` |
| `include` | Comma-separated repos to include | `""` |
| `exclude` | Comma-separated repos to exclude | `""` |
| `upgrade-commands` | JSON of repo-specific upgrade commands | `"{}"` |
| `package-name` | The package name to update | |
| `version` | The version to update to | |
| `owner` | Owner of target repositories | `planningcenter` |
| `allow-major` | Allow major version updates | `false` |
| `package-json-path` | Path to package.json | `package.json` |
| `node-version` | Node version for upgrade commands | `24` |

Consumer repos can define a `.pco-release.config.yml` file for custom upgrade behavior:

```yml
# .pco-release.config.yml
upgrade_command: "yarn tr upgrade"
```

### create-release-candidate

Creates an RC prerelease version from a PR branch. Publishes as `v{version}-rc.N`.

```yml
- uses: planningcenter/pco-release-action/create-release-candidate@v1
  with:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

| Input | Description | Default |
|---|---|---|
| `GITHUB_TOKEN` | **(required)** GitHub token | |
| `package-json-path` | Path to package.json | `package.json` |
| `yarn-version-command` | Command to bump version | `yarn version` |
| `node-version` | Node.js version | `24` |

### create-qa-release

Creates a QA prerelease version for testing a specific branch. Publishes as `v{version}-qa-{pr_number}.N`.

```yml
- uses: planningcenter/pco-release-action/create-qa-release@v1
  with:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

| Input | Description | Default |
|---|---|---|
| `GITHUB_TOKEN` | **(required)** GitHub token | |
| `package-json-path` | Path to package.json | `package.json` |
| `yarn-version-command` | Command to bump version | `yarn version` |
| `node-version` | Node.js version | `24` |

### node-cache

Utility action that caches `node_modules` for faster workflow runs.

```yml
- uses: planningcenter/pco-release-action/node-cache@v1
  with:
    cache: yarn
    node-version: "24"
```

| Input | Description | Default |
|---|---|---|
| `cache` | Package manager (`npm`, `yarn`, `pnpm`, or `""`) | `yarn` |
| `node-version` | Node.js version | `24` |

### reporting

Posts deployment results as a comment on the originating PR.

```yml
- uses: planningcenter/pco-release-action/reporting@v1
  with:
    results-json: ${{ steps.deploy.outputs.json }}
    pr-number: ${{ github.event.pull_request.number }}
    actor: ${{ github.actor }}
    version-tag: v1.2.3
    release-type: Release
```

| Input | Description | Default |
|---|---|---|
| `results-json` | **(required)** JSON string with deployment results | |
| `pr-number` | **(required)** PR number to comment on | |
| `actor` | **(required)** GitHub user who triggered the release | |
| `version-tag` | **(required)** Version tag (e.g. `v1.0.0`) | |
| `release-type` | **(required)** Type of release (`Release`, `RC`, `QA`) | |
| `proto-tag` | Proto release tag if applicable | |
| `custom-message` | Custom message instead of default protonova URL | |

---

## NPM Authentication via OIDC Trusted Publishing

PCO-Release workflows support [npm trusted publishing](https://docs.npmjs.com/trusted-publishers) using OpenID Connect (OIDC), eliminating the need for long-lived `PLANNINGCENTER_NPM_TOKEN` secrets.

### Prerequisites

- **Lerna v9+** in consuming repos (for lerna-based workflows)
- **npm CLI v11.5.1+** and **Node v22.14.0+** (for non-lerna workflows)

### Configuring a package on npmjs.com

Each npm package must be configured to trust the GitHub Actions workflow that publishes it.

1. Go to [npmjs.com](https://www.npmjs.com) and navigate to your package's **Settings**
2. Find the **Trusted Publisher** section
3. Select **GitHub Actions** as the provider
4. Fill in the required fields:
   - **Organization or user**: `planningcenter`
   - **Repository**: Your repository name (e.g., `tapestry`)
   - **Workflow filename**: The filename of the *calling* workflow in your repo (e.g., `pco-release-qa.yml`)
   - **Environment name**: Leave blank unless using GitHub environments
5. Save the configuration

> **Important:** For reusable workflows (like those in this repo), npm validates the *calling* workflow's filename, not the reusable workflow that contains the `npm publish` command. Make sure the workflow filename matches exactly, including the `.yml` extension.

> **Note:** Each package can only have one trusted publisher configured at a time. npm does not validate the configuration when you save it -- errors will only appear when you attempt to publish.

### Configuring your calling workflow

Your calling workflow must include the `id-token: write` permission. This is required on both the calling and reusable workflows for OIDC to function.

```yml
# Example: .github/workflows/pco-release-qa.yml
on:
  issue_comment:
    types: [created]

jobs:
  create-qa-release-and-deploy:
    if: github.event.issue.pull_request && contains(github.event.comment.body, '@pco-release qa')
    permissions:
      contents: write
      pull-requests: write
      id-token: write  # Required for OIDC trusted publishing
    uses: planningcenter/pco-release-action/.github/workflows/lerna-qa-release.yml@v1
    secrets: inherit
```

### Post-migration security (recommended)

Once trusted publishing is working:

1. Navigate to your package's **Settings** -> **Publishing access** on npmjs.com
2. Select **"Require two-factor authentication and disallow tokens"**
3. [Revoke any existing automation tokens](https://docs.npmjs.com/revoking-access-tokens) that are no longer needed

### Troubleshooting

- **"Unable to authenticate" (ENEEDAUTH)**: Verify the workflow filename on npmjs.com matches your calling workflow exactly, including the `.yml` extension. All fields are case-sensitive.
- **Self-hosted runners**: Not currently supported by npm trusted publishing. You must use GitHub-hosted runners.
- **Private dependencies**: Trusted publishing only applies to `npm publish`. You still need a read-only token for installing private packages via `npm ci`/`npm install`.

---

## Configuration Reference

### Labels

| Label | Purpose |
|---|---|
| `pco-release-patch` | Bump the patch version (e.g. 1.0.0 -> 1.0.1) |
| `pco-release-minor` | Bump the minor version (e.g. 1.0.0 -> 1.1.0) |
| `pco-release-major` | Bump the major version (e.g. 1.0.0 -> 2.0.0) |
| `pco-release-pending` | Applied automatically to release PRs; triggers release on merge |
| `pco-release-urgent` | Force deploy PRs to all repos |

### PR Comment Commands

| Command | Where | What it does |
|---|---|---|
| `@pco-release rc` | Release PR | Creates an RC version and deploys to staging |
| `@pco-release qa` | Any PR | Creates a QA version and deploys to protonova |
| `@pco-release deploy` | Release PR (Lerna) | Deploys the RC to staging |

### Required Secrets

| Secret | Purpose |
|---|---|
| `PCO_DEPENDENCIES_APP_ID` | GitHub App ID for cross-repo operations |
| `PCO_DEPENDENCIES_PRIVATE_KEY` | GitHub App private key |
| `PLANNINGCENTER_NPM_TOKEN` | NPM registry token -- being replaced by [OIDC trusted publishing](#npm-authentication-via-oidc-trusted-publishing) |

---

## Contributing

1. Edit TypeScript source in a workspace's `src/` directory
2. Run `yarn build` to compile to `dist/`
3. Commit both `src/` and `dist/` changes (dist is committed so GitHub Actions can run without `node_modules`)
4. Test the action by referencing your branch in a consuming repo
5. After merging to `main`, update the version tag (e.g. `v1`)
