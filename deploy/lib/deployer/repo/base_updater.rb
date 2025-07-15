require "yaml"

class Deployer
  class Repo
    class BaseUpdater
      def initialize(name, config:, package_name:, repo:)
        @name = name
        @config = config
        @package_name = package_name
        @repo = repo
      end

      def run
        clone_repo
        Dir.chdir(name) { make_changes_if_updatable }
        cleanup
      rescue StandardError => e
        cleanup
        raise e
      end

      def pr_number
      end

      def pr_url
        return if pr_number.nil?

        "https://github.com/#{owner}/#{name}/pull/#{pr_number}"
      end

      def skipped
        false
      end

      def ignore_pr_level?
        true
      end

      protected

      attr_reader :name, :config, :package_name, :repo

      def make_changes
        raise NotImplementedError
      end

      def clone_suffix
        ""
      end

      def branch_name
        raise NotImplementedError
      end

      def make_changes_if_updatable
        if updatable?
          make_changes
        else
          log "Skipping major upgrade for #{name}"
        end
      end

      def clone_repo
        log "Cloning #{name}"
        command_line.execute(
          "git clone https://oauth2:#{config.github_token}@github.com/#{owner}/#{name}.git#{clone_suffix}",
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
        !config.disable_for_major? ||
          !VersionCompare.new(
            package_name: package_name,
            version: version
          ).major_upgrade?
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
