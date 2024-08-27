class Deployer
  class Repo
    def initialize(name, config:)
      @name = name
      @config = config
    end

    def update_package
      updater.run
    end

    def success_message
      "Successfully updated #{package_name} to #{version} in #{name}#{updater.message_suffix}"
    end

    attr_reader :name

    private

    attr_reader :config, :pr_number

    def updater
      @updater ||= updater_class.new(name, config: config)
    end

    def updater_class
      PullRequestUpdater
    end

    def package_name
      config.package_name
    end

    def version
      config.version
    end
  end
end
