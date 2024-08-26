class Deployer
  class BaseError < StandardError
  end

  class FailedToCloneRepo < BaseError
  end

  class CreateBranchFailure < BaseError
  end

  class UpgradeCommandFailure < BaseError
  end

  class CommitChangesFailure < BaseError
  end

  class PushBranchFailure < BaseError
  end

  class FailedToCreatePRError < BaseError
  end

  class AutoMergeFailure < BaseError
  end
end
