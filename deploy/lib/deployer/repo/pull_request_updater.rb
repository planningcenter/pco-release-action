class Deployer
  class Repo
    class PullRequestUpdater < BaseUpdater
      attr_reader :pr_number

      private

      attr_writer :pr_number

      def make_changes
        create_branch
        run_upgrade_command
        commit_and_push_changes
        create_pr
        automerge_pr
      end

      def clone_suffix
        " --depth=1"
      end

      def branch_name
        unsanitized_branch_name = "pco-release-#{package_name}-#{version}"
        unsanitized_branch_name.gsub(/[^a-zA-Z0-9]/, "-")
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

        self.pr_number = response.number
      end

      def automerge_pr
        return unless automerge

        log "Merging PR #{pr_number}"
        command_line.execute(
          "gh pr merge #{pr_number} --auto --merge",
          error_class: AutoMergeFailure
        )
      end

      def pr_title
        "[Automated] bump #{package_name} to #{version}"
      end

      def pr_body
        "This is an automated PR that updates #{package_name} to version #{version}. Please ensure that all checks pass."
      end

      def client
        config.client
      end

      def automerge
        config.automerge
      end
    end
  end
end
