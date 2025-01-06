describe Deployer::Repo do
  let(:config) do
    instance_double(
      Deployer::Config,
      package_names: ["test-pkg"],
      version: "1.2.7"
    )
  end

  describe "#failure?" do
    it "returns false if the repo update is successful" do
      updater = instance_double(Deployer::Repo::MergeUpdater, run: nil)
      repo =
        described_class.new(
          "test",
          config: config,
          updater: updater,
          package_name: "test-pkg"
        )

      repo.update_package

      expect(repo.failure?).to be false
    end

    it "returns true when updater raises an error" do
      updater = instance_double(Deployer::Repo::MergeUpdater)
      allow(updater).to receive(:run).and_raise(StandardError)
      repo =
        described_class.new(
          "test",
          config: config,
          updater: updater,
          package_name: "test-pkg"
        )

      repo.update_package

      expect(repo.failure?).to be true
    end
  end

  describe "#success?" do
    it "returns true if the repo update is successful" do
      updater = instance_double(Deployer::Repo::MergeUpdater, run: nil)
      repo =
        described_class.new(
          "test",
          config: config,
          updater: updater,
          package_name: "test-pkg"
        )

      repo.update_package

      expect(repo.success?).to be true
    end

    it "returns false when updater raises an error" do
      updater = instance_double(Deployer::Repo::MergeUpdater)
      allow(updater).to receive(:run).and_raise(StandardError)
      repo =
        described_class.new(
          "test",
          config: config,
          updater: updater,
          package_name: "test-pkg"
        )

      repo.update_package

      expect(repo.success?).to be false
    end
  end

  describe "#error_message" do
    it "returns nothing when successful" do
      updater = instance_double(Deployer::Repo::MergeUpdater, run: true)
      repo =
        described_class.new(
          "test",
          config: config,
          updater: updater,
          package_name: "test-pkg"
        )

      repo.update_package

      expect(repo.error_message).to be_nil
    end

    it "returns the error message when failed" do
      updater = instance_double(Deployer::Repo::MergeUpdater, run: false)
      repo =
        described_class.new(
          "test",
          config: config,
          updater: updater,
          package_name: "test-pkg"
        )
      allow(updater).to receive(:run).and_raise(
        Deployer::PushBranchFailure,
        "You don't have permissions to push to this branch"
      )

      repo.update_package

      expect(
        repo.error_message
      ).to include "[Push Branch Failure]: You don't have permissions to push to this branch"
    end
  end

  describe "#success_message" do
    it "returns a success message" do
      updater = instance_double(Deployer::Repo::MergeUpdater)
      repo =
        described_class.new(
          "test",
          config: config,
          updater: updater,
          package_name: "test-pkg"
        )

      expect(
        repo.success_message
      ).to eq "Successfully updated test-pkg to 1.2.7 in test"
    end
  end

  describe "#pr_number" do
    it "returns the PR number" do
      updater = instance_double(Deployer::Repo::MergeUpdater, pr_number: 123)
      repo =
        described_class.new(
          "test",
          config: config,
          updater: updater,
          package_name: "test-pkg"
        )

      expect(repo.pr_number).to eq 123
    end
  end

  describe "#pr_url" do
    it "returns the PR URL" do
      updater =
        instance_double(
          Deployer::Repo::MergeUpdater,
          pr_url: "http://github.com/org/repo/pull/123"
        )
      repo =
        described_class.new(
          "test",
          config: config,
          updater: updater,
          package_name: "test-pkg"
        )

      expect(repo.pr_url).to eq "http://github.com/org/repo/pull/123"
    end
  end
end
