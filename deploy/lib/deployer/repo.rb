class Deployer
  class Repo
    def initialize(name, config:)
      @name = name
      @config = config
    end

    def update_package
      run
    rescue StandardError => e
      cleanup
      raise e
    end

    def success_message
      "Successfully updated #{package_name} to #{version} in #{name} (https://github.com/#{owner}/#{name}/pull/#{pr_number})"
    end

    attr_reader :name

    private

    attr_reader :config, :pr_number

    def run
      clone_repo
      Dir.chdir(name) do
        create_branch
        run_upgrade_command
        commit_and_push_changes
        create_pr
        automerge_pr
      end
      cleanup
    end

    def clone_repo
      log "Cloning #{name}"
      command_line.execute(
        "git clone https://#{config.github_token}:x-oauth-basic@github.com/#{owner}/#{name}.git --depth=1",
        error_class: FailedToCloneRepo
      )
    end

    def create_branch
      log "Creating branch #{branch_name}"
      command_line.execute(
        "git checkout -b #{branch_name}",
        error_class: CreateBranchFailure
      )
    end

    def run_upgrade_command
      log "Running #{upgrade_command}"
      command_line.execute(
        "#{upgrade_command} #{package_name}@#{version}",
        error_class: UpgradeCommandFailure
      )
    end

    def commit_and_push_changes
      command_line.execute(
        "git commit -am 'bump #{package_name} to #{version}'",
        error_class: CommitChangesFailure
      )
      command_line.execute(
        "git push origin #{branch_name} -f",
        error_class: PushBranchFailure
      )
    end

    def create_pr
      response =
        client.create_pull_request(
          "#{owner}/#{name}",
          "main",
          branch_name,
          pr_title,
          pr_body
        )
      raise FailedToCreatePRError, response if response.number.nil?

      @pr_number = response.number
    end

    def automerge_pr
      return unless automerge

      log "Merging PR #{pr_number}"
      command_line.execute(
        "gh pr merge #{pr_number} --auto --merge",
        error_class: AutoMergeFailure
      )
    end

    def cleanup
      FileUtils.rm_rf(name)
    end

    def branch_name
      unsanitized_branch_name = "pco-release-#{package_name}-#{version}"
      unsanitized_branch_name.gsub(/[^a-zA-Z0-9]/, "-")
    end

    def upgrade_command
      upgrade_commands[name].nil? ? "yarn upgrade" : upgrade_commands[name]
    end

    def pr_title
      "[Automated] bump #{package_name} to #{version}"
    end

    def pr_body
      "This is an automated PR that updates #{package_name} to version #{version}. Please ensure that all checks pass."
    end

    def log(message)
      config.log(message)
    end

    def owner
      config.owner
    end

    def package_name
      config.package_name
    end

    def version
      config.version
    end

    def upgrade_commands
      config.upgrade_commands
    end

    def client
      config.client
    end

    def automerge
      config.automerge
    end

    def command_line
      @command_line ||= CommandLine.new(config)
    end
  end
end
