class Deployer
  class Repo
    class VersionCompare
      def initialize(package_name:, version:)
        @version = Gem::Version.new(version)
        @package_name = package_name
      end

      def major_upgrade?
        return true if current_version.nil?

        current_version.segments.first != version.segments.first
      end

      private

      attr_reader :package_name, :version

      def current_version
        @current_version ||=
          begin
            yarn_lock_file = File.read("yarn.lock")
            current_version_string =
              yarn_lock_file.match(
                /"#{package_name}@\d+\.\d+\.\d+":\n\s\sversion "([^"]+)"/m
              )[
                1
              ]
            Gem::Version.new(current_version_string)
          end
      end
    end
  end
end
