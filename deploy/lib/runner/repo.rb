class Runner
  class Repo
    def initialize(name, automerge:, owner:, github_token:)
      @name = name
      @automerge = automerge
      @owner = owner
      @github_token = github_token
    end

    def update_package
      run
      log "Successfully updated #{package_name} to #{version} in #{name}"
    rescue CreateBranchFailure,
           UpgradeCommandFailure,
           CommitChangesFailure,
           PushBranchFailure,
           FailedToCreatePRError,
           AutoMergeFailure => e
      reset_folder
      raise e
    end

    attr_reader :name

    private

    def run
      clone_repo
      Dir.chdir(name) do
        create_branch
        run_upgrade_command
        commit_and_push_changes
        create_pr
        automerge_pr
      end
      reset_folder
    end

    def clone_repo
      url = "github.com/#{owner}/#{name}.git"
      log "Cloning #{name}"
      stdout, status =
        Open3.capture2(
          "git clone https://#{github_token}:x-oauth-basic@#{url} --depth=1"
        )
      raise FailedToCloneRepo, stdout unless status.success?
    end

    def enter_folder
      stdout, status = Open3.capture2("ls")
      puts stdout
      puts "Going into folder: #{name}"
      Open3.capture2("cd #{name}")
    end

    def create_branch
      log "Creating branch #{branch_name}"
      stdout, status = Open3.capture2("git checkout -b #{branch_name}")
      raise CreateBranchFailure, stdout unless status.success?
    end

    def run_upgrade_command
      command = upgrade_commands[name].presence || "yarn_upgrade"
      log "Running #{upgrade_commands[name]}"
      stdout, status = Open3.capture2("#{command} #{package_name}@#{version}")

      raise UpgradeCommandFailure, stdout unless status.success?
    end

    def commit_and_push_changes
      stdout, status =
        Open3.capture2("git commit -am 'bump #{package_name} to #{version}'")
      raise CommitChangesFailure, stdout unless status.success?

      stdout2, status2 = Open3.capture2("git push origin #{branch_name} -f")
      raise PushBranchFailure, stdout2 unless status2.success?
    end

    def create_pr
      raise FailedToCreatePRError, "Don't want to accidentally do this"
      response =
        client.create_pull_request(
          "#{owner}/#{name}",
          "main",
          branch_name,
          pr_title,
          pr_body
        )
      raise FailedToCreatePRError, response if response.status >= 400

      @pr_number = response["number"]
    end

    def automerge_pr
      return unless automerge

      log "Merging PR #{pr_number}"
      stdout, status = Open3.capture2("gh pr merge #{pr_number} --auto --merge")
      raise AutoMergeFailure, stdout unless status.success?
    end

    def reset_folder
      FileUtils.rm_rf(name)
    end

    attr_reader :pr_number, :automerge, :owner, :github_token

    def log(message)
      puts "[PCO-Release] #{message}"
    end

    def branch_name
      unsanitized_branch_name = "pco-release-#{package_name}-#{version}"
      unsanitized_branch_name.gsub(/[^a-zA-Z0-9]/, "-")
    end

    def pr_title
      "[Automated] bump #{package_name} to #{version}"
    end

    def pr_body
      "This is an automated PR that updates #{package_name} to version #{version}. Please ensure that all checks pass."
    end
  end
end
