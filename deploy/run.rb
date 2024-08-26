require_relative "./lib/runner"

Runner.new(
  github_token: ENV["GITHUB_TOKEN"],
  package_name: ENV["PACKAGE_NAME"],
  version: ENV["PACKAGE_VERSION"],
  owner: ENV["OWNER"],
  only: ENV["ONLY"].split(","),
  automerge: ENV["AUTOMERGE"] == "true",
  upgrade_commands: JSON.parse(ENV["UPGRADE_COMMANDS"])
).run
