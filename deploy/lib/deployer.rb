require "octokit"
require "open3"
require "base64"
require "dependabot/source"
require "dependabot/file_fetchers"
require "dependabot/file_parsers"
require "dependabot/file_updaters"
require "dependabot/pull_request_creator"
require "dependabot/update_checkers"
require "dependabot/npm_and_yarn"
require "dependabot/bun"
require_relative "deployer/command_line"
require_relative "deployer/config"
require_relative "deployer/errors"
require_relative "deployer/repo"
require_relative "deployer/repo/config_file"
require_relative "deployer/repo/base_updater"
require_relative "deployer/repo/dependabot_pull_request_updater"
require_relative "deployer/repo/dependabot_proxy"
require_relative "deployer/repo/merge_updater"
require_relative "deployer/repo/pull_request_updater"
require_relative "deployer/repo/version_compare"
require_relative "deployer/reporter"
require_relative "deployer/repos"

class Deployer
  def initialize(config)
    @config = config
    @failed_repos = []
    @successful_repos = []
  end

  def run
    log_deployer_start
    repos.each do |repo|
      log_repo_start(repo)
      repo.update_package
      log_result(repo)
    end
    Reporter.new(repos)
  end

  def repos
    @repos ||= Repos.new(config).find
  end

  private

  attr_reader :config
  attr_accessor :failed_repos, :successful_repos

  def report_results
    return unless failed_repos.any?

    failed_repos_list =
      failed_repos.map { |r| "#{r.name}: #{r.package_name}" }.join("\n- ")
    raise "[PCO-Release]: Failed in the following repos:\n- #{failed_repos_list}"
  end

  def package_names
    config.package_names
  end

  def version
    config.version
  end

  def log(message)
    config.log(message)
  end

  def log_deployer_start
    log "Updating #{package_names.join(", ")} to #{version} in the following repositories: #{repo_names.join(", ")}"
  end

  def log_repo_start(repo)
    log "updating #{repo.package_name} in #{repo.name}"
  end

  def log_result(repo)
    if repo.success?
      log repo.success_message
    else
      log "Failed to update #{repo.package_name} in #{repo.name}: #{repo.error_message}"
    end
  end

  def repo_names
    repos.map(&:name).uniq
  end
end
