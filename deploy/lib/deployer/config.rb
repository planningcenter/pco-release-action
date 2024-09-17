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
      exclude: [],
      allow_major: false
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
      @allow_major = allow_major
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
                :change_method,
                :allow_major

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

    def credentials
      [
        {
          "type" => "git_source",
          "host" => "github.com",
          "username" => "x-access-token",
          "password" => github_token
        },
        {
          "type" => "npm_registry",
          "registry" => "npm.pkg.github.com",
          "token" => github_token,
          "replaces_base" => true
        }
      ]
    end
  end
end
