describe Deployer::Repo::VersionCompare do
  describe "#major_upgrade?" do
    it "works when detecting a yarn 3 file" do
      version_compare =
        described_class.new(
          package_name: "@planningcenter/tapestry-react",
          version: "4.6.0",
          lock_file_path: "spec/fixtures/yarn3.lock"
        )

      expect(version_compare.major_upgrade?).to eq(false)
    end

    it "works when detecting a yarn file" do
      version_compare =
        described_class.new(
          package_name: "@planningcenter/tapestry-react",
          version: "4.6.0",
          lock_file_path: "spec/fixtures/yarn.lock"
        )

      expect(version_compare.major_upgrade?).to eq(false)
    end

    it "supports the deprecated yarn_lock_file_path parameter" do
      version_compare =
        described_class.new(
          package_name: "@planningcenter/tapestry-react",
          version: "4.6.0",
          yarn_lock_file_path: "spec/fixtures/yarn.lock"
        )

      expect(version_compare.major_upgrade?).to eq(false)
    end

    it "works when detecting an npm package-lock.json (lockfileVersion 3)" do
      version_compare =
        described_class.new(
          package_name: "@planningcenter/tapestry-react",
          version: "4.6.0",
          lock_file_path: "spec/fixtures/package-lock.json"
        )

      expect(version_compare.major_upgrade?).to eq(false)
    end

    it "works when detecting an npm package-lock.json (lockfileVersion 1)" do
      version_compare =
        described_class.new(
          package_name: "@planningcenter/tapestry-react",
          version: "4.6.0",
          lock_file_path: "spec/fixtures/package-lock-v1.json"
        )

      expect(version_compare.major_upgrade?).to eq(false)
    end

    it "detects major upgrade from npm package-lock.json" do
      version_compare =
        described_class.new(
          package_name: "@planningcenter/tapestry-react",
          version: "5.0.0",
          lock_file_path: "spec/fixtures/package-lock.json"
        )

      expect(version_compare.major_upgrade?).to eq(true)
    end

    it "raises error when npm lock file does not contain the dependency" do
      version_compare =
        described_class.new(
          package_name: "@planningcenter/nonexistent",
          version: "1.0.0",
          lock_file_path: "spec/fixtures/package-lock.json"
        )

      expect { version_compare.major_upgrade? }.to raise_error(
        Deployer::VersionCompareFailure,
        "[Deployer::VersionCompareFailure]: Could not find @planningcenter/nonexistent in package-lock.json"
      )
    end

    it "raises error when lock file does not contain the dependency" do
      version_compare =
        described_class.new(
          package_name: "@planningcenter/tapestry-react",
          version: "4.6.0",
          lock_file_path: "spec/fixtures/empty_lock.lock"
        )

      expect { version_compare.major_upgrade? }.to raise_error(
        Deployer::VersionCompareFailure,
        "[Deployer::VersionCompareFailure]: Could not find @planningcenter/tapestry-react in empty_lock.lock"
      )
    end

    it "raises error when npm lock file is malformed" do
      version_compare =
        described_class.new(
          package_name: "@planningcenter/tapestry-react",
          version: "4.6.0",
          lock_file_path: "spec/fixtures/package-lock-malformed.json"
        )

      expect { version_compare.major_upgrade? }.to raise_error(
        Deployer::VersionCompareFailure,
        "[Deployer::VersionCompareFailure]: Failed to parse package-lock-malformed.json"
      )
    end

    context "when there is no lock file" do
      it "raises error" do
        version_compare =
          described_class.new(
            package_name: "@planningcenter/tapestry-react",
            version: "4.6.0",
            lock_file_path: "spec/fixtures/missing.lock"
          )

        expect { version_compare.major_upgrade? }.to raise_error(
          Deployer::VersionCompareFailure,
          "[Deployer::VersionCompareFailure]: No lock file found"
        )
      end
    end
  end
end
