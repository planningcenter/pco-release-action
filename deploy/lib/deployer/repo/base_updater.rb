class Deployer
  class Repo
    class BaseUpdater
      def initialize(name, config:)
        @name = name
        @config = config
      end

      def run
        make_changes
      rescue StandardError => e
        cleanup
        raise e
      end

      protected

      attr_reader :name, :config

      def make_changes
        raise NotImplementedError
      end

      def clone_suffix
        ""
      end

      def branch_name
        raise NotImplementedError
      end

      def clone_repo
        log "Cloning #{name}"
        command_line.execute(
          "git clone https://#{config.github_token}:x-oauth-basic@github.com/#{owner}/#{name}.git#{clone_suffix}",
          error_class: FailedToCloneRepo
        )
      end

      def create_branch
        log "Creating branch #{branch_name}"
        command_line.execute(
          "git checkout #{branch_name} || git checkout -b #{branch_name}",
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

      def cleanup
        FileUtils.rm_rf(name)
      end

      def upgrade_command
        upgrade_commands[name].nil? ? "yarn upgrade" : upgrade_commands[name]
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

      def command_line
        @command_line ||= CommandLine.new(config)
      end
    end
  end
end
