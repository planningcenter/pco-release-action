require "octokit"
require "open3"
require "base64"
require_relative "runner/repos"
require_relative "runner/repo"
require_relative "runner/errors"

class Runner
  def initialize(
    github_token:,
    owner:,
    package_name:,
    version:,
    automerge: false,
    only: [],
    upgrade_commands: {}
  )
    @github_token = github_token
    @owner = owner
    @only = only
    @package_name = package_name
    @version = version
    @automerge = automerge
    @upgrade_commands = upgrade_commands
  end

  def run
    log "Updating #{package_name} to #{version} in the following repositories: #{repos.join(", ")}"
    repos.each do |repo|
      log "updating #{package_name} in #{repo}"
      repo.update_package
    rescue Runner::RunnerError => e
      log "Failed to update #{package_name} in #{repo}: #{e}"
      raise e
    end
  end

  def repos
    @repos ||=
      Repos.new(
        client: client,
        owner: owner,
        package_name: package_name,
        automerge: automerge,
        github_token: github_token,
        only: only,
        version: version,
        upgrade_commands: upgrade_commands
      ).find
  end

  private

  attr_reader :github_token,
              :owner,
              :package_name,
              :only,
              :automerge,
              :version,
              :upgrade_commands

  def client
    @client ||=
      Octokit::Client
        .new(access_token: github_token)
        .tap { |c| c.auto_paginate = true }
  end

  def log(message)
    puts "[PCO-Release] #{message}"
  end
end
