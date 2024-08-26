require "octokit"
require "open3"
require "base64"
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
    repos.each do |repo|
      log "updating #{package_name} in #{repo.name}"
      repo.update_package
    rescue BaseError, StandardError => e
      log "Failed to update #{package_name} in #{repo}: #{e} #{e.message} #{e.backtrace}"
    end
  end

  def repos
    @repos ||= Repos.new(config).find
  end

  private

  attr_reader :config

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
