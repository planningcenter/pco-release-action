# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## About This Project

PCO-Release is a collection of GitHub Actions that automate the release process for Planning Center's JavaScript/TypeScript libraries. It manages version bumping, changelog updates, PR creation, npm publishing, and coordinated deployments across consuming repositories.

## Development Commands

### Building
```bash
yarn build                # Build all workspace packages
yarn workspace release-by-pr build          # Build specific workspace
yarn workspace dependabot-automation build
yarn workspace release-by-pr-lerna build
```

### Linting & Formatting
```bash
yarn lint         # Run ESLint across all workspaces
yarn format       # Format all TypeScript files with Prettier
```

### Testing
```bash
yarn workspace release-by-pr test           # Run tests in release-by-pr workspace
yarn workspace dependabot-automation test   # Run tests in dependabot-automation workspace
```

Individual workspaces use Jest for testing.

## Architecture

### Monorepo Structure

This is a Yarn workspaces monorepo with three main packages:

1. **`release-by-pr/`** - Core action that creates release PRs when changes are merged to main
2. **`dependabot-automation/`** - Automatically updates CHANGELOG.md for dependabot PRs
3. **`lerna/release-by-pr/`** - Lerna-specific variant for monorepo releases

Additionally, there are standalone GitHub Actions (not part of workspaces):
- `create-release-on-merge/` - Creates GitHub releases when release PRs are merged
- `create-release-candidate/` - Publishes RC versions to npm with `@next` tag
- `create-qa-release/` - Creates QA releases for testing specific branches
- `deploy/` - Coordinates deployments across consuming repos
- `sync-with-labels/` - Updates version bump type based on PR labels
- `reporting/` - Generates deployment reports
- `node-cache/` - Caches node_modules for faster workflow runs

### Build System

Each TypeScript workspace uses `@vercel/ncc` to compile the action into a single distributable file in `dist/`. This is required for GitHub Actions to run the code without a node_modules directory.

Build command: `ncc build --source-map src/main.ts`

### Release Workflow

The typical release flow for a library using these actions:

1. **Developer merges PR to main** → `release-by-pr` action creates a "pco-release--internal" PR with version bump and changelog
2. **Labels control version bump** → Apply `pco-release-patch`, `pco-release-minor`, or `pco-release-major` label
3. **Label changes** → `sync-with-labels` action updates the version in the release PR
4. **Release PR merged** → `create-release-on-merge` action publishes to npm and creates GitHub release
5. **`deploy` action** (optional) → Opens PRs to update the dependency across consuming repos

### Testing Release Candidates & QA Releases

- **Release Candidates (RC)**: Triggered by commenting `@pco-release rc` on a release PR. Publishes to npm with `@next` tag and deploys to staging environments.
- **QA Releases**: Triggered by commenting `@pco-release qa` on any PR. Creates a branch-specific prerelease for testing in protonova environments.

### Configuration Options

Actions accept inputs for customizing build/test/publish commands:
- `build-command` (default: `yarn build`)
- `install-command` (default: `yarn install --check-files`)
- `test-command` (default: `yarn test`)
- `publish-command` (default: `npm publish`)
- `cache` (default: `yarn`) - Package manager for caching
- `only`, `include`, `exclude` - Filter which repos get updated during deploys
- `upgrade-commands` - JSON mapping of repo-specific upgrade commands (for monorepos)

### Lerna Support

The `lerna/release-by-pr/` workspace provides special handling for Lerna monorepos where multiple packages need coordinated version bumps. The Lerna-specific workflows in `.github/workflows/lerna-*.yml` handle:
- Detecting which packages changed
- Version bumping across interdependent packages
- Publishing multiple packages with the same tag

### Secrets & Authentication

Actions use GitHub App authentication via secrets:
- `PCO_DEPENDENCIES_APP_ID` - GitHub App ID
- `PCO_DEPENDENCIES_PRIVATE_KEY` - GitHub App private key

These allow the actions to trigger other workflows and create PRs with proper permissions.

## Important Notes

- **Always build before pushing**: Run `yarn build` before committing changes to ensure `dist/` folders are up to date
- **Action versioning**: Consumers reference actions via `@v1` tag (e.g., `planningcenter/pco-release-action/release-by-pr@v1`)
- **CHANGELOG.md requirement**: PRs to main typically require CHANGELOG.md updates (enforced by separate workflow in consuming repos)
- **Dependabot automation**: The `dependabot-automation` action automatically adds changelog entries for dependency updates
- **Reusable workflows**: `.github/workflows/*.yml` are reusable workflows that consuming repos can call with `uses:`

## Making Changes

1. Edit TypeScript source in a workspace's `src/` directory
2. Run `yarn build` to compile to `dist/`
3. Test the action in a consuming repository
4. Commit both `src/` and `dist/` changes (dist is committed to allow GitHub Actions to run)
5. Update version tag (`v1`, `v2`, etc.) after merging to main
