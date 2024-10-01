require_relative "pull_request_updater"

class Deployer
  class Repo
    class DependabotPullRequestUpdater < PullRequestUpdater
      def run
        setup_runner
        verify_upgrade_satisfies
        create_pr
        automerge_pr if config.automerge
      end

      attr_reader :pr_url

      private

      attr_writer :pr_url

      def source
        @source ||=
          Dependabot::Source.new(
            provider: "github",
            repo: "#{config.owner}/#{name}",
            directory: "/",
            branch: "main"
          )
      end

      def package_manager
        "npm_and_yarn"
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
      end

      def setup_runner
        Dir.chdir(Dependabot::NpmAndYarn::NativeHelpers.native_helpers_root) do
          CommandLine.new(config).execute(
            "npm install --silent",
            error_class: AutoMergeFailure
          )
        end
      end

      def checker
        @checker ||=
          Dependabot::UpdateCheckers.for_package_manager(package_manager).new(
            dependency: dependency,
            dependency_files: fetcher.files,
            credentials: credentials
          )
      end

      def create_pr
        if requirements_to_unlock == :update_not_possible
          return log "Update not possible for #{dependency.name}"
        end

        return log "No valid updates" if updated_dependencies.none?

        log "Creating PR"
        pr = pr_creator.create
        self.pr_number = pr.number
        self.pr_url = pr.html_url
      end

      def requirements_to_unlock
        if !checker.requirements_unlocked_or_can_be?
          locked_requirements
        elsif checker.can_update?(requirements_to_unlock: :own)
          :own
        elsif checker.can_update?(requirements_to_unlock: :all)
          :all
        else
          :update_not_possible
        end
      end

      def locked_requirements
        if checker.can_update?(requirements_to_unlock: :none)
          :none
        else
          :update_not_possible
        end
      end

      def updated_dependencies
        @updated_dependencies ||=
          checker
            .updated_dependencies(
              requirements_to_unlock: requirements_to_unlock
            )
            .select do |dependency|
              if config.disable_for_major?
                !VersionCompare.new(
                  current_version:
                    Gem::Version.new(dependency.previous_version),
                  package_name: name,
                  version: checker.latest_version
                ).major_upgrade?
              else
                true
              end
            end
      end

      def updater
        @updater ||=
          Dependabot::FileUpdaters.for_package_manager(package_manager).new(
            dependencies: updated_dependencies,
            dependency_files: fetcher.files,
            credentials: credentials
          )
      end

      def updated_files
        updater.updated_dependency_files
      end

      def pr_creator
        Dependabot::PullRequestCreator.new(
          source: source,
          base_commit: fetcher.commit,
          dependencies: updated_dependencies,
          files: updated_files,
          credentials: credentials,
          assignees: nil,
          author_details: {
            name: "dependabot[bot]",
            email: "dependabot[bot]@users.noreply.github.com"
          },
          pr_message_header: pr_body
        )
      end

      def automerge_pr
        return unless automerge

        log "Merging PR #{pr_number}"
        command_line.execute(
          "gh pr merge #{pr_number} --auto --merge --repo #{config.owner}/#{name}",
          error_class: AutoMergeFailure
        )
      rescue AutoMergeFailure => e
        log "Failed to auto-merge PR: #{e.message}"
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

      def sanitize_yarnrc_yml(fetcher)
        # publishing uses the yarnrc.yml file to set the yarnPath
        # but this behavior is broken in dependabot:
        # https://github.com/dependabot/dependabot-core/issues/10632
        yarnrc_yml_file = fetcher.files.find { |f| f.name == ".yarnrc.yml" }
        return if yarnrc_yml_file.nil?

        yarnrc_yml_file.content =
          yarnrc_yml_file.content.gsub("yarnPath:", "# yarnPath:")
      end

      def verify_upgrade_satisfies
        if Gem::Version.new(resolvable_version) >= Gem::Version.new(version)
          return
        end

        raise RequirementsNotMet, resolvable_version
      end

      def resolvable_version
        checker.latest_resolvable_version
      end
    end
  end
end
