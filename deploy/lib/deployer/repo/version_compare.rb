require "json"

class Deployer
  class Repo
    class VersionCompare
      def initialize(
        package_name:,
        version:,
        current_version: nil,
        lock_file_path: nil,
        yarn_lock_file_path: nil
      )
        @version = Gem::Version.new(version)
        @lock_file_path = lock_file_path || yarn_lock_file_path
        @current_version = current_version
        @package_name = package_name
      end

      def major_upgrade?
        return true if current_version.nil?

        current_version.segments.first != version.segments.first
      end

      private

      attr_reader :package_name, :version

      def lock_file_path
        @lock_file_path ||= detect_lock_file
      end

      def detect_lock_file
        if File.exist?("package-lock.json")
          "package-lock.json"
        elsif File.exist?("yarn.lock")
          "yarn.lock"
        end
      end

      def current_version
        @current_version ||= find_current_version
      end

      def find_current_version
        raise_no_lock_file if lock_file_path.nil?

        if File.basename(lock_file_path).start_with?("package-lock")
          find_current_version_from_npm
        else
          find_current_version_from_yarn
        end
      end

      def find_current_version_from_npm
        lock_data = JSON.parse(File.read(lock_file_path))

        version_string =
          if lock_data["packages"]
            entry = lock_data["packages"]["node_modules/#{package_name}"]
            entry&.fetch("version", nil)
          end

        if version_string.nil? && lock_data["dependencies"]
          entry = lock_data["dependencies"][package_name]
          version_string = entry&.fetch("version", nil)
        end

        package_not_found if version_string.nil?

        Gem::Version.new(version_string)
      rescue Errno::ENOENT
        raise_no_lock_file
      rescue JSON::ParserError
        raise VersionCompareFailure,
              "Failed to parse #{File.basename(lock_file_path)}"
      end

      def find_current_version_from_yarn
        match =
          yarn_lock_file.match(
            /"#{Regexp.escape(package_name)}@[^"]+":?\n\s+version:?\s"?([^"\n]+)/m
          )
        package_not_found if match.nil?

        current_version_string = match[1]
        Gem::Version.new(current_version_string)
      end

      def yarn_lock_file
        @yarn_lock_file ||= File.read(lock_file_path)
      rescue Errno::ENOENT
        raise_no_lock_file
      end

      def raise_no_lock_file
        raise VersionCompareFailure, "No lock file found"
      end

      def package_not_found
        lock_file_name = File.basename(lock_file_path)
        raise VersionCompareFailure,
              "Could not find #{package_name} in #{lock_file_name}"
      end
    end
  end
end
