# Deploy action

## Summary

This Github action helps to automate the automatic updating of a JavaScript library.
It searches all repos of an owner and creates PRs to update to the new version of the library.

## Features

- Auto-merge capability to automatically update a new release in all repos that depend on the library
- Clear failure reports tell which repos failed to update and why.
- Support consumer repositories that use NPM, Yarn, or Bun as their package manager

## Usage

To use, add a github workflow to your current publish action like this:

```yml
# .github/workflows/publish.yml

name: Publish

---
jobs:
  publish-to-npm: ...

  auto-deploy-after-release:
    needs: publish-to-npm
    runs-on: ubuntu-latest
    permissions: read-all
    steps:
      - uses: planningcenter/pco-release-action/deploy@v1
        with:
          app-id: ${{ secrets.PCO_DEPENDENCIES_APP_ID }}
          private-key: ${{ secrets.PCO_DEPENDENCIES_PRIVATE_KEY }}
          automerge: true
          upgrade-commands: '{"tapestry-react":"yarn tr upgrade"}' # this is assuming that you're upgrading
```

## Config Files in Consumers

Some consumers of the library will have specific commands that they need to use to upgrade to the newest version. Instead of making each library know that, you can add a config file to the consumer repo called `.pco-release.config.yml`.

```yml
# `./.pco-release.config.yml`
upgrade_command: "yarn tr upgrade"
```

In this case, whenever upgrading, it will use the new upgrade command.

This file is not necessary, but allows for customization.
