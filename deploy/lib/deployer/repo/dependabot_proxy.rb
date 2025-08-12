class Deployer
  class Repo
    class DependabotProxy
      def initialize(name, config:, package_name:)
        @config = config
        @name = name
        @package_name = package_name
        self.class.setup(config)
      end

      def self.setup(config)
        return if @setup_run

        Dir.chdir(Dependabot::NpmAndYarn::NativeHelpers.native_helpers_root) do
          CommandLine.new(config).execute(
            "npm install --silent",
            error_class: AutoMergeFailure
          )
        end
        @setup_run = true
      end

      def source
        @source ||=
          Dependabot::Source.new(
            provider: "github",
            repo: "#{config.owner}/#{name}",
            directory: "/",
            branch: "main"
          )
      end

      def fetcher
        @fetcher ||=
          begin
            fetcher =
              Dependabot::FileFetchers.for_package_manager(package_manager).new(
                source: source,
                credentials: credentials
              )
            sanitize_yarnrc_yml(fetcher)
            fetcher
          end
      end

      def parser
        @parser ||=
          Dependabot::FileParsers.for_package_manager(package_manager).new(
            dependency_files: fetcher.files,
            source: source,
            credentials: credentials
          )
      end

      def dependency
        @dependency ||=
          parser
            .parse
            .select(&:top_level?)
            .find { |dep| dep.name == package_name }
      rescue Dependabot::DependencyFileNotFound, Dependabot::BranchNotFound
        nil
      end

      def checker
        @checker ||=
          Dependabot::UpdateCheckers.for_package_manager(package_manager).new(
            dependency: dependency,
            dependency_files: fetcher.files,
            credentials: credentials
          )
      end

      def credentials
        [
          {
            "type" => "git_source",
            "host" => "github.com",
            "username" => "x-access-token",
            "password" => config.github_token
          },
          {
            "type" => "npm_registry",
            "registry" => "npm.pkg.github.com",
            "token" => config.github_token,
            "replaces_base" => true
          }
        ].map { |creds| Dependabot::Credential.new(creds) }
      end

      def package_manager
        "npm_and_yarn"
      end

      private

      attr_reader :config, :name, :package_name

      def sanitize_yarnrc_yml(fetcher)
        # publishing uses the yarnrc.yml file to set the yarnPath
        # but this behavior is broken in dependabot:
        # https://github.com/dependabot/dependabot-core/issues/10632
        yarnrc_yml_file = fetcher.files.find { |f| f.name == ".yarnrc.yml" }
        return if yarnrc_yml_file.nil?

        yarnrc_yml_file.content =
          yarnrc_yml_file.content.gsub("yarnPath:", "# yarnPath:")
                                 .gsub("- path:", "# - path:")
                                 .gsub("spec: ", "# spec: ")
      end
    end
  end
end
