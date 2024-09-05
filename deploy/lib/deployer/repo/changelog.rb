class Deployer
  class Repo
    class Changelog
      def initialize(message:, changelog: read)
        @message = message
        @changelog = changelog
      end

      def update
        return false if changelog.empty?

        File.open(changelog_path, "w") { |file| file.write(update_changelog) }
        true
      end

      def update_changelog
        if current_release.include?("### Dependencies")
          "#{unchanged_intro}#{updated_current_release}#{old_releases}"
        else
          "#{unchanged_intro}#{current_release || "\n\n"}### Dependencies\n\n- #{message}\n\n#{old_releases}"
        end
      end

      private

      attr_reader :message, :changelog

      def read
        return "" unless File.exist?(changelog_path)

        File.read(changelog_path)
      end

      def changelog_path
        "CHANGELOG.md"
      end

      def entry_title
        "## Unreleased"
      end

      def unchanged_intro
        changelog.slice(0, unchanged_beginning_end_index)
      end

      def updated_current_release
        current_release.sub(/(###\sDependencies\n)(.*?)(\n\n.*)/m) do
          "#{Regexp.last_match(1)}#{Regexp.last_match(2)}\n- #{message}#{Regexp.last_match(3)}"
        end
      end

      def current_release
        changelog.slice(
          unchanged_beginning_end_index...old_releases_start_index
        )
      end

      def remaining
        changelog.slice(unchanged_beginning_end_index..-1)
      end

      def old_releases
        changelog.slice(old_releases_start_index..-1)
      end

      def unchanged_beginning_end_index
        @unchanged_beginning_end_index ||=
          changelog.index(entry_title) + entry_title.length
      end

      def old_releases_start_index
        (remaining.index(/^##(?!#)/) || remaining.length) +
          unchanged_beginning_end_index
      end
    end
  end
end
