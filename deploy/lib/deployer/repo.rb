class Deployer
  class Repo
    def initialize(name, package_name:, config:, updater: nil, config_file: ConfigFile.new(name, config: config))
      @name = name
      @config = config
      @package_name = package_name
      @updater = updater || default_updater
      @config_file = config_file
    end

    def update_package
      updater.run

      self.success = true
    rescue StandardError => e
      self.error_message = e.message
      self.success = false
    end

    def attempt_to_update?
      return false if config.only.any? && !config.only.include?(name)
      return false if config.exclude.include?(name)
      return false unless pr_level_reached?

      config.log("Checking if dependency exists #{name} (#{package_name})")
      !dependabot_proxy.dependency.nil?
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
      success
    end

    def failure?
      !success?
    end

    def dependabot_proxy
      @dependabot_proxy ||= Deployer::Repo::DependabotProxy.new(name, config: config, package_name: package_name)
    end

    attr_reader :name, :error_message, :package_name

    private

    attr_reader :config, :updater, :config_file
    attr_accessor :success
    attr_writer :error_message

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

      config_file.pr_level != "urgent"
    end
  end
end
