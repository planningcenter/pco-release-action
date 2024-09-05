describe Deployer::Repo::Changelog do
  describe "#update" do
    it "writes an updated changelog to the file" do
      original_changelog = <<~CHANGELOG
        \# Changelog

        \#\# Unreleased

      CHANGELOG
      message = "bump things to 1.1.0"
      expected_changelog = <<~CHANGELOG
        \# Changelog

        \#\# Unreleased

        \#\#\# Dependencies

        - #{message}

      CHANGELOG

      allow(File).to receive(:exist?).with("CHANGELOG.md").and_return(true)
      allow(File).to receive(:read).with("CHANGELOG.md").and_return(
        original_changelog
      )
      file_double = double("file")
      allow(File).to receive(:open).with("CHANGELOG.md", "w").and_yield(
        file_double
      )
      allow(file_double).to receive(:write)

      changelog = Deployer::Repo::Changelog.new(message: message)

      expect(changelog.update).to eq(true)
      expect(File).to have_received(:open).with("CHANGELOG.md", "w")
      expect(file_double).to have_received(:write).with(expected_changelog)
    end
  end

  describe "#update_changelog" do
    it "updates the changelog when no data exists in the current release" do
      original_changelog = <<~CHANGELOG
        \# Changelog

        \#\# Unreleased

      CHANGELOG
      message = "bump things to 1.1.0"
      expected_changelog = <<~CHANGELOG
        \# Changelog

        \#\# Unreleased

        \#\#\# Dependencies

        - #{message}

      CHANGELOG

      changelog =
        Deployer::Repo::Changelog.new(
          message: message,
          changelog: original_changelog
        )

      expect(changelog.update_changelog).to eq(expected_changelog)
    end

    it "updates the changelog when the current release has a dependency update" do
      original_changelog = <<~CHANGELOG
        \# Changelog

        \#\# Unreleased

        \#\#\# Dependencies

        - bump other_things to 4.5.1

      CHANGELOG
      message = "bump things to 1.1.0"
      expected_changelog = <<~CHANGELOG
        \# Changelog

        \#\# Unreleased

        \#\#\# Dependencies

        - bump other_things to 4.5.1
        - #{message}

      CHANGELOG

      changelog =
        Deployer::Repo::Changelog.new(
          message: message,
          changelog: original_changelog
        )

      expect(changelog.update_changelog).to eq(expected_changelog)
    end

    it "updates the changelog when dependencies were updated in a previous release" do
      original_changelog = <<~CHANGELOG
        \# Changelog

        \#\# Unreleased

        ### Security

        - fixed a security issue

        ## v1.0.0

        \#\#\# Dependencies

        - bump other_things to 4.5.1

      CHANGELOG
      message = "bump things to 1.1.0"
      expected_changelog = <<~CHANGELOG
        \# Changelog

        \#\# Unreleased

        ### Security

        - fixed a security issue

        \#\#\# Dependencies

        - #{message}

        ## v1.0.0

        \#\#\# Dependencies

        - bump other_things to 4.5.1

      CHANGELOG

      changelog =
        Deployer::Repo::Changelog.new(
          message: message,
          changelog: original_changelog
        )

      expect(changelog.update_changelog).to eq(expected_changelog)
    end
  end
end
