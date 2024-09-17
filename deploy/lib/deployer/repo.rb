class Deployer
  class Repo
    def initialize(name, config:, updater: nil)
      @name = name
      @config = config
      @updater = updater || default_updater
    end

    def update_package
      updater.run

      self.success = true
    rescue StandardError => e
      self.error_message = e.message
      self.success = false
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

    attr_reader :name, :error_message

    private

    attr_reader :config, :updater
    attr_accessor :success
    attr_writer :error_message

    def default_updater
      updater_class.new(name, config: config)
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

    def package_name
      config.package_name
    end

    def version
      config.version
    end
  end
end
