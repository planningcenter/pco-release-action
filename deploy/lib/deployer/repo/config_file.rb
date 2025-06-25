class Deployer
  class Repo
    class ConfigFile
      def initialize(name, config:)
        @name = name
        @config = config
      end

      def pr_level
        config_file["pr_level"]
      end

      private

      attr_reader :name, :config

      def config_file
        @config_file ||= fetch_config_file
      end

      def fetch_config_file
        content = config.client.contents(
          "#{config.owner}/#{name}",
          path: ".pco-release.config.yml",
          ref: "main"
        )

        YAML.safe_load(Base64.decode64(content[:content]))
      rescue Octokit::NotFound
        { "pr_level" => "all" }
      end
    end
  end
end
