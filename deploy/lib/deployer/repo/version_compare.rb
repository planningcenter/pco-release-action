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
        current_version_string =
          yarn_lock_file.match(
            /"#{package_name}@[^"]+":\n\s\sversion "([^"]+)"/m
          )[
            1
          ]
        Gem::Version.new(current_version_string)
      end

      def yarn_lock_file
        @yarn_lock_file ||= File.read(yarn_lock_file_path)
      rescue Errno::ENOENT
        raise Deployer::VersionCompareFailure, "No yarn.lock file found"
      end
    end
  end
end
