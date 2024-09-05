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
            current_version_string =
              File.read("yarn.lock").match(
                /\n#{package_name}@\d+\.\d+\.\d+:\n\s\sversion "(.+)"/
              )[
                1
              ]
            Gem::Version.new(current_version_string)
          end
      end
    end
  end
end
