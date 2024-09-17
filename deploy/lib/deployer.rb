require "octokit"
require "open3"
require "base64"
require_relative "deployer/command_line"
require_relative "deployer/config"
require_relative "deployer/errors"
require_relative "deployer/repo"
require_relative "deployer/repo/base_updater"
require_relative "deployer/repo/dependabot_pull_request_updater"
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

    raise "[PCO-Release]: Failed in the following repos:\n- #{failed_repos.map(&:name).join("\n- ")}"
  end

  def package_name
    config.package_name
  end

  def version
    config.version
  end

  def log(message)
    config.log(message)
  end

  def log_deployer_start
    log "Updating #{package_name} to #{version} in the following repositories: #{repos.map(&:name).join(", ")}"
  end

  def log_repo_start(repo)
    log "updating #{package_name} in #{repo.name}"
  end

  def log_result(repo)
    if repo.success?
      log repo.success_message
    else
      log "Failed to update #{package_name} in #{repo.name}: #{repo.error_message}"
    end
  end
end
