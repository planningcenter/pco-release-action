class Deployer
  class Config
    def initialize( # rubocop:disable Metrics/ParameterLists, Metrics/MethodLength
      github_token:,
      owner:,
      package_name:,
      version:,
      change_method: "pr",
      branch_name: "main",
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
      @branch_name = branch_name
      @change_method = change_method
    end

    attr_reader :github_token,
                :owner,
                :package_name,
                :version,
                :automerge,
                :branch_name,
                :only,
                :upgrade_commands,
                :include,
                :exclude,
                :change_method

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
