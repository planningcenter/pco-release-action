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
  end
end
