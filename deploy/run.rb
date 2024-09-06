require_relative "./lib/deployer"

config =
  Deployer::Config.new(
    github_token: ENV["GITHUB_TOKEN"],
    package_name: ENV["PACKAGE_NAME"],
    version: ENV["PACKAGE_VERSION"],
    owner: ENV["OWNER"],
    only: ENV["ONLY"].split(","),
    automerge: ENV["AUTOMERGE"] == "true",
    upgrade_commands: JSON.parse(ENV["UPGRADE_COMMANDS"]),
    branch_name: ENV["BRANCH_NAME"],
    change_method: ENV["CHANGE_METHOD"],
    include: ENV["INCLUDE"].split(","),
    exclude: ENV["EXCLUDE"].split(","),
    allow_major: ENV["ALLOW_MAJOR"] == "true"
  )
reporter = Deployer.new(config).run

reporter.output_to_github
