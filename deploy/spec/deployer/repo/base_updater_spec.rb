describe Deployer::Repo::BaseUpdater do
  describe "#upgrade_command" do
    context "when there is a config file specifying a command" do
      it "returns the command with replacements" do
        config =
          instance_double(
            Deployer::Config,
            version: "1.0.1",
            package_names: ["test"]
          )
        updater =
          described_class.new("repo", config: config, package_name: "test", repo: instance_double(Deployer::Repo))
        allow(File).to receive(:exist?).with(".pco-release.config.yml").and_return(true)
        allow(File).to receive(:exist?).with("package-lock.json").and_return(false)
        allow(YAML).to receive(:load_file).and_return(
          "upgrade_command" =>
            "some other upgrade --name={{package_name}} --version={{version}}"
        )

        expect(updater.send(:upgrade_command)).to eq(
          "some other upgrade --name=test --version=1.0.1"
        )
      end
    end

    context "when there is a config, but no upgrade command" do
      it "returns the default yarn upgrade for yarn repos" do
        config =
          instance_double(
            Deployer::Config,
            version: "1.0.1",
            package_names: ["test"],
            upgrade_commands: {
            }
          )
        updater =
          described_class.new("repo", config: config, package_name: "test", repo: instance_double(Deployer::Repo))
        allow(File).to receive(:exist?).with(".pco-release.config.yml").and_return(true)
        allow(File).to receive(:exist?).with("package-lock.json").and_return(false)
        allow(YAML).to receive(:load_file).and_return({})

        expect(updater.send(:upgrade_command)).to eq("yarn upgrade test@1.0.1")
      end

      it "returns the default npm install for npm repos" do
        config =
          instance_double(
            Deployer::Config,
            version: "1.0.1",
            package_names: ["test"],
            upgrade_commands: {
            }
          )
        updater =
          described_class.new("repo", config: config, package_name: "test", repo: instance_double(Deployer::Repo))
        allow(File).to receive(:exist?).with(".pco-release.config.yml").and_return(true)
        allow(File).to receive(:exist?).with("package-lock.json").and_return(true)
        allow(YAML).to receive(:load_file).and_return({})

        expect(updater.send(:upgrade_command)).to eq("npm install test@1.0.1")
      end
    end

    context "when the config contains an upgrade command for the repo" do
      it "returns the command " do
        config =
          instance_double(
            Deployer::Config,
            version: "1.0.1",
            package_names: ["test"],
            upgrade_commands: {
              "repo" => "some other upgrade"
            }
          )
        updater =
          described_class.new("repo", config: config, package_name: "test", repo: instance_double(Deployer::Repo))
        allow(File).to receive(:exist?).with(".pco-release.config.yml").and_return(false)

        expect(updater.send(:upgrade_command)).to eq(
          "some other upgrade test@1.0.1"
        )
      end
    end

    context "when the config contains an upgrade command for a different repo" do
      it "returns the default yarn upgrade for yarn repos" do
        config =
          instance_double(
            Deployer::Config,
            version: "1.0.1",
            package_names: ["test"],
            upgrade_commands: {
              "other" => "some other upgrade"
            }
          )
        updater =
          described_class.new("repo", config: config, package_name: "test", repo: instance_double(Deployer::Repo))
        allow(File).to receive(:exist?).with(".pco-release.config.yml").and_return(false)
        allow(File).to receive(:exist?).with("package-lock.json").and_return(false)

        expect(updater.send(:upgrade_command)).to eq("yarn upgrade test@1.0.1")
      end

      it "returns the default npm install for npm repos" do
        config =
          instance_double(
            Deployer::Config,
            version: "1.0.1",
            package_names: ["test"],
            upgrade_commands: {
              "other" => "some other upgrade"
            }
          )
        updater =
          described_class.new("repo", config: config, package_name: "test", repo: instance_double(Deployer::Repo))
        allow(File).to receive(:exist?).with(".pco-release.config.yml").and_return(false)
        allow(File).to receive(:exist?).with("package-lock.json").and_return(true)

        expect(updater.send(:upgrade_command)).to eq("npm install test@1.0.1")
      end
    end
  end
end
