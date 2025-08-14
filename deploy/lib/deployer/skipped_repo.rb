class Deployer
  class SkippedRepo
    def initialize(name)
      @name = name
    end

    attr_reader :name

    def exclude_from_reporting?
      false
    end

    def package_name
      ""
    end

    def update_package
      nil
    end

    def success?
      false
    end

    def failure?
      false
    end

    def skipped?
      true
    end

    def message
      "Skipped because token does not have permission to access #{name}. Ensure with platform " \
        "that the \"Planning Center Dependencies\" Github App has permission to access this " \
        "repository."
    end

    def error_message
      message
    end
  end
end
