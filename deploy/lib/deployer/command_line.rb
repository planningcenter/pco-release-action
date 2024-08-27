class Deployer
  class CommandLine
    def initialize(config)
      @config = config
    end

    def execute(command, error_class:)
      stdout, stderr, status = Open3.capture3(command)
      raise error_class, stderr unless status.success?

      config.log stdout
    end

    private

    attr_reader :config
  end
end
