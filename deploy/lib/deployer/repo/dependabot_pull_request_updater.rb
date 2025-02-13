require_relative "pull_request_updater"

class Deployer
  class Repo
    class DependabotPullRequestUpdater < PullRequestUpdater
      def run
        verify_upgrade_satisfies
        create_pr
        automerge_pr if config.automerge
      end

      attr_reader :pr_url

      private

      attr_writer :pr_url

      def dependabot_proxy
        repo.dependabot_proxy
      end

      def source
        dependabot_proxy.source
      end

      def fetcher
        dependabot_proxy.fetcher
      end

      def dependency
        dependabot_proxy.dependency
      end

      def checker
        dependabot_proxy.checker
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

      def updater
        @updater ||=
          Dependabot::FileUpdaters.for_package_manager(dependabot_proxy.package_manager).new(
            dependencies: updated_dependencies,
            dependency_files: fetcher.files,
            credentials: credentials
          )
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
        dependabot_proxy.credentials
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
