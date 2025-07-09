require 'byebug'
class Deployer
  class Repo
    def initialize(name, package_name:, config:, updater: nil, config_file: ConfigFile.new(name, config: config), dependabot_proxy: Deployer::Repo::DependabotProxy.new(name, config: config, package_name: package_name))
      @name = name
      @config = config
      @package_name = package_name
      @updater = updater || default_updater
      @config_file = config_file
      @status = :pending
      @dependabot_proxy = dependabot_proxy
    end

    def update_package
      return skipped! unless attempt_to_update?
      updater.run

      if updater.skipped
        self.status = :skipped
        @repo_upgrade_status = :version_bump_not_possible
        return
      end

      self.status = :success
      self.success = true
    rescue StandardError => e
      self.error_message = e.message
      self.success = false
      self.status = :failure
    end

    def exclude_from_reporting?
      [:excluded_explicitly, :excluded_no_dependency].include?(repo_upgrade_status)
    end

    def attempt_to_update?
      repo_upgrade_status == :attempt_to_update
    end

    def success_message
      "Successfully updated #{package_name} to #{version} in #{name}"
    end

    def pr_number
      updater.pr_number
    end

    def pr_url
      updater.pr_url
    end

    def success?
      status == :success
    end

    def failure?
      status == :failure
    end

    def skipped?
      status == :skipped
    end

    def message
      case status
      when :skipped
        skipped_message
      when :success
        success_message
      when :failure
        error_message
      end
    end

    attr_reader :name, :error_message, :package_name, :dependabot_proxy

    private

    attr_reader :config, :updater, :config_file
    attr_accessor :success, :status
    attr_writer :error_message

    def skipped!
      self.status = :skipped
    end

    def skipped_message
      case repo_upgrade_status
      when :excluded_explicitly
        "Skipped #{name} because it is excluded from reporting"
      when :excluded_by_pr_level
        "Skipped #{name} because repo manages non-urgent updates"
      when :excluded_no_dependency
        "Skipped #{name} because it does not have the dependency"
      when :version_bump_not_possible
        "Skipped #{name} because the version bump is not possible (usually because of a major version bump)"
      end
    end

    def repo_upgrade_status
      @repo_upgrade_status ||= begin
        return :excluded_explicitly if config.only.any? && !config.only.include?(name)
        return :excluded_explicitly if config.exclude.include?(name)
        return :excluded_by_pr_level unless pr_level_reached?

        config.log("Checking if dependency exists #{name} (#{package_name})")
        return :excluded_no_dependency if dependabot_proxy.dependency.nil?

        :attempt_to_update
      end
    end

    def default_updater
      updater_class.new(name, config: config, package_name: package_name, repo: self)
    end

    def updater_class
      case config.change_method
      when "merge"
        MergeUpdater
      when "revert"
        PullRequestUpdater
      else
        DependabotPullRequestUpdater
      end
    end

    def version
      config.version
    end

    def pr_level_reached?
      return true if config.urgent
      return true if updater.ignore_pr_level?

      config_file.pr_level != "urgent"
    end
  end
end
