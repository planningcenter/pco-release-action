require_relative "./lib/deployer"

def run_for_packages
  configs.each do |config|
    reporter = Deployer.new(config).run
    reporter.output_to_github
  end
end

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
  allow_major: ENV["ALLOW_MAJOR"] == "true"
}

def configs
  package_names = JSON.parse(ENV["PACKAGE_NAMES"])
  package_names.map do |package_name|
    Deployer::Config.new(**COMMON_CONFIG, package_name: package_name)
  end
rescue JSON::ParserError, TypeError
  Deployer::Config.new(**COMMON_CONFIG, package_name: ENV["PACKAGE_NAME"])
end

run_for_packages
