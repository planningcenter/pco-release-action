class Deployer
  class BaseError < StandardError
    def initialize(message = nil)
      super(message ? "[#{friendly_name}]: #{message}" : self.class.name)
    end

    private

    def friendly_name
      self.class.name
    end
  end

  class FailedToCloneRepo < BaseError
  end

  class CreateBranchFailure < BaseError
    def friendly_name
      "Create Branch Failure"
    end
  end

  class UpgradeCommandFailure < BaseError
    def friendly_name
      "Failed While Running Upgrade Command"
    end
  end

  class CommitChangesFailure < BaseError
    def friendly_name
      "Failed To Commit Changes"
    end
  end

  class PushBranchFailure < BaseError
    def friendly_name
      "Push Branch Failure"
    end
  end

  class FailedToCreatePRError < BaseError
  end

  class AutoMergeFailure < BaseError
  end

  class VersionCompareFailure < BaseError
  end
end
