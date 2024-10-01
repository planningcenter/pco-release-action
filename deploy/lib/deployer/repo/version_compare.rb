class Deployer
  class Repo
    class VersionCompare
      def initialize(
        package_name:,
        version:,
        current_version: nil,
        yarn_lock_file_path: "yarn.lock"
      )
        @version = Gem::Version.new(version)
        @yarn_lock_file_path = yarn_lock_file_path
        @current_version = current_version
        @package_name = package_name
      end

      def major_upgrade?
        return true if current_version.nil?

        current_version.segments.first != version.segments.first
      end

      private

      attr_reader :package_name, :version, :yarn_lock_file_path

      def current_version
        @current_version ||= find_current_version
      end

      def find_current_version
        match =
          yarn_lock_file.match(
            /"#{Regexp.escape(package_name)}@[^"]+":?\n\s+version:?\s"?([^"\n]+)/m
          )
        package_not_found if match.nil?

        current_version_string = match[1]
        Gem::Version.new(current_version_string)
      end

      def yarn_lock_file
        @yarn_lock_file ||= File.read(yarn_lock_file_path)
      rescue Errno::ENOENT
        raise VersionCompareFailure, "No yarn.lock file found"
      end

      def package_not_found
        raise VersionCompareFailure,
              "Could not find #{package_name} in yarn.lock"
      end
    end
  end
end
