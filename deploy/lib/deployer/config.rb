class Deployer
  class Config
    def initialize( # rubocop:disable Metrics/ParameterLists, Metrics/MethodLength
      github_token:,
      owner:,
      version:,
      package_names:,
      change_method: "pr",
      branch_name: "main",
      automerge: false,
      only: [],
      upgrade_commands: {},
      include: [],
      exclude: [],
      allow_major: false,
      urgent: false
    )
      @github_token = github_token
      @owner = owner
      @version = version
      @automerge = automerge
      @only = only
      @upgrade_commands = upgrade_commands
      @include = include
      @exclude = exclude
      @branch_name = branch_name
      @change_method = change_method
      @allow_major = allow_major
      @package_names = package_names
      @urgent = urgent
    end

    attr_reader :github_token,
                :owner,
                :package_names,
                :version,
                :automerge,
                :branch_name,
                :only,
                :upgrade_commands,
                :include,
                :exclude,
                :change_method,
                :allow_major,
                :urgent

    def client
      @client ||=
        Octokit::Client
          .new(access_token: github_token)
          .tap { |c| c.auto_paginate = true }
    end

    def log(message)
      puts "[PCO-Release] #{message}"
    end

    def disable_for_major?
      !allow_major
    end
  end
end
