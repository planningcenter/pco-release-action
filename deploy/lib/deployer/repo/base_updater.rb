require "yaml"

class Deployer
  class Repo
    class BaseUpdater
      def initialize(name, config:)
        @name = name
        @config = config
      end

      def run
        clone_repo
        Dir.chdir(name) { make_changes if updatable? }
        cleanup
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

      def config_file
        return {} unless File.exist?(".pco-release.config.yml")

        @config_file ||= YAML.load_file(".pco-release.config.yml")
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
          upgrade_command,
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

      def updatable?
        !config.disable_for_major? || !VersionCompare.new(config).major_upgrade?
      end

      def cleanup
        FileUtils.rm_rf(name)
      end

      def upgrade_command
        unless config_file["upgrade_command"].nil?
          return(build_upgrade_command_from_config_file)
        end

        if upgrade_commands[name].nil?
          "yarn upgrade #{package_name}@#{version}"
        else
          "#{upgrade_commands[name]} #{package_name}@#{version}"
        end
      end

      def build_upgrade_command_from_config_file
        replacements = {
          "{{version}}" => version,
          "{{package_name}}" => package_name
        }

        config_file["upgrade_command"].tap do |command|
          replacements.each { |key, value| command.gsub!(key, value) }
        end
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
