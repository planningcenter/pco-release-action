class Deployer
  class Repo
    class MergeUpdater < BaseUpdater
      private

      def make_changes
        setup_runner
        create_branch
        run_upgrade_command
        commit_and_push_changes
      end

      def branch_name
        config.branch_name
      end

      def setup_runner
        Dir.chdir(Dependabot::NpmAndYarn::NativeHelpers.native_helpers_root) do
          CommandLine.new(config).execute(
            "npm install --silent",
            error_class: AutoMergeFailure
          )
        end
      end
    end
  end
end
