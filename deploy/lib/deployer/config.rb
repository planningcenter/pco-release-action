class Deployer
  class Config
    def initialize(
      github_token:,
      owner:,
      package_name:,
      version:,
      automerge: false,
      only: [],
      upgrade_commands: {},
      include: [],
      exclude: []
    )
      @github_token = github_token
      @owner = owner
      @package_name = package_name
      @version = version
      @automerge = automerge
      @only = only
      @upgrade_commands = upgrade_commands
      @include = include
      @exclude = exclude
    end

    attr_reader :github_token,
                :owner,
                :package_name,
                :version,
                :automerge,
                :only,
                :upgrade_commands,
                :include,
                :exclude

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
end
