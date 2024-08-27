# Deploy action

## Summary

This Github action helps to automate the automatic updating of a JavaScript library.
It searches all repos of an owner and creates PRs to update to the new version of the library.

## Features

- Auto-merge capability to automatically update a new release in all repos that depend on the library
- Clear failure reports tell which repos failed to update and why.

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
          github-token: ${{ secrets.GITHUB_TOKEN }}
          automerge: true
          upgrade-commands: '{"tapestry-react":"yarn tr upgrade"}' # this is assuming that you're upgrading
```
