describe Deployer::Repo::VersionCompare do
  describe "#major_upgrade?" do
    it "works when detecting a yarn file" do
      version_compare =
        described_class.new(
          package_name: "@planningcenter/tapestry-react",
          version: "4.6.0",
          yarn_lock_file_path: "spec/fixtures/yarn.lock"
        )

      expect(version_compare.major_upgrade?).to eq(false)
    end

    it "raises error when lock file does not contain the dependency" do
      version_compare =
        described_class.new(
          package_name: "@planningcenter/tapestry-react",
          version: "4.6.0",
          yarn_lock_file_path: "spec/fixtures/empty_lock.lock"
        )

      expect { version_compare.major_upgrade? }.to raise_error(
        Deployer::VersionCompareFailure,
        "[Deployer::VersionCompareFailure]: Could not find @planningcenter/tapestry-react in yarn.lock"
      )
    end

    context "when there is no lock file" do
      it "raises error" do
        version_compare =
          described_class.new(
            package_name: "@planningcenter/tapestry-react",
            version: "4.6.0",
            yarn_lock_file_path: "spec/fixtures/missing.lock"
          )

        expect { version_compare.major_upgrade? }.to raise_error(
          Deployer::VersionCompareFailure,
          "[Deployer::VersionCompareFailure]: No yarn.lock file found"
        )
      end
    end
  end
end
