require "octokit"
require "open3"
require "base64"
require_relative "deployer/command_line"
require_relative "deployer/config"
require_relative "deployer/errors"
require_relative "deployer/repo"
require_relative "deployer/repos"

class Deployer
  def initialize(config)
    @config = config
  end

  def run
    log "Updating #{package_name} to #{version} in the following repositories: #{repos.map(&:name).join(", ")}"
    errors = []
    repos.each do |repo|
      log "updating #{package_name} in #{repo.name}"
      repo.update_package
      log repo.success_message
    rescue BaseError, StandardError => e
      errors.push(e)
      log failure_message(error: e, repo: repo)
    end

    raise MultipleErrors errors if errors.any?
  end

  def repos
    @repos ||= Repos.new(config).find
  end

  private

  attr_reader :config

  def failure_message(error:, repo:)
    "Failed to update #{package_name} in #{repo.name}: #{error.class} #{error.message}"
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
end
