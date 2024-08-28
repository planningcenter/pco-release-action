class Deployer
  class Repo
    class MergeUpdater < BaseUpdater
      def message_suffix
        ""
      end

      private

      def make_changes
        clone_repo
        Dir.chdir(name) do
          create_branch
          run_upgrade_command
          commit_and_push_changes
        end
        cleanup
      end

      def branch_name
        config.branch_name
      end
    end
  end
end
