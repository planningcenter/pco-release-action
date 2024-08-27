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

  class MultipleErrors < BaseError
    attr_reader :errors

    def initialize(errors = [])
      @errors = errors
      super(build_message)
    end

    private

    def build_message
      "[PCO-Release]: Failed to deploy to all repos. Look through the logs for failed repos. " \
        "#{@errors.map(&:message).join(", ")}"
    end
  end
end
