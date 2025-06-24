require_relative "./lib/deployer"

COMMON_CONFIG = {
  github_token: ENV["GITHUB_TOKEN"],
  version: ENV["PACKAGE_VERSION"],
  owner: ENV["OWNER"],
  only: ENV["ONLY"].split(","),
  automerge: ENV["AUTOMERGE"] == "true",
  upgrade_commands: JSON.parse(ENV["UPGRADE_COMMANDS"]),
  branch_name: ENV["BRANCH_NAME"],
  change_method: ENV["CHANGE_METHOD"],
  include: ENV["INCLUDE"].split(","),
  exclude: ENV["EXCLUDE"].split(","),
  allow_major: ENV["ALLOW_MAJOR"] == "true",
  urgent: ENV["URGENT"] == "true"
}

def run_for_packages
  config = Deployer::Config.new(**COMMON_CONFIG, package_names: package_names)
  reporter = Deployer.new(config).run
  reporter.output_to_github
end

def package_names
  return ENV["PACKAGE_NAMES"].split(",") unless ENV["PACKAGE_NAMES"]&.empty?

  [ENV["PACKAGE_NAME"]]
end

run_for_packages
