class Runner
  class RunnerError < StandardError
  end

  class FailedToCloneRepo < RunnerError
  end

  class CreateBranchFailure < RunnerError
  end

  class UpgradeCommandFailure < RunnerError
  end

  class CommitChangesFailure < RunnerError
  end

  class PushBranchFailure < RunnerError
  end

  class FailedToCreatePRError < RunnerError
  end

  class AutoMergeFailure < RunnerError
  end
end
