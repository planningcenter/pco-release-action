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

    context "when .pco-release.config.yml specifies node_version" do
      it "wraps the command with nvm" do
        config =
          instance_double(
            Deployer::Config,
            version: "1.0.1",
            package_names: ["test"],
            upgrade_commands: {
              "other" => "some other upgrade"
            }
          )
        allow(config).to receive(:log)
        updater =
          described_class.new("repo", config: config, package_name: "test", repo: instance_double(Deployer::Repo))
        allow(File).to receive(:exist?).with(".pco-release.config.yml").and_return(true)
        allow(File).to receive(:exist?).with("package-lock.json").and_return(false)
        allow(YAML).to receive(:load_file).and_return("node_version" => "22")

        expect(updater.send(:with_node_version, updater.send(:upgrade_command))).to eq(
          "bash -lc '. \"$NVM_DIR/nvm.sh\" && nvm install 22 && nvm use 22 && yarn upgrade test@1.0.1'"
        )
      end
    end

    context "when .pco-release.config.yml does not specify node_version" do
      it "returns the command unchanged" do
        config =
          instance_double(
            Deployer::Config,
            version: "1.0.1",
            package_names: ["test"],
            upgrade_commands: {}
          )
        updater =
          described_class.new("repo", config: config, package_name: "test", repo: instance_double(Deployer::Repo))
        allow(File).to receive(:exist?).with(".pco-release.config.yml").and_return(true)
        allow(File).to receive(:exist?).with("package-lock.json").and_return(false)
        allow(YAML).to receive(:load_file).and_return({})

        expect(updater.send(:with_node_version, updater.send(:upgrade_command))).to eq(
          "yarn upgrade test@1.0.1"
        )
      end
    end

    context "when .pco-release.config.yml has invalid node_version" do
      it "raises an error" do
        config =
          instance_double(
            Deployer::Config,
            version: "1.0.1",
            package_names: ["test"],
            upgrade_commands: {}
          )
        allow(config).to receive(:log)
        updater =
          described_class.new("repo", config: config, package_name: "test", repo: instance_double(Deployer::Repo))
        allow(File).to receive(:exist?).with(".pco-release.config.yml").and_return(true)
        allow(File).to receive(:exist?).with("package-lock.json").and_return(false)
        allow(YAML).to receive(:load_file).and_return("node_version" => ";&rm -rf /")

        expect { updater.send(:with_node_version, updater.send(:upgrade_command)) }.to raise_error(
          Deployer::UpgradeCommandFailure, /Invalid node_version/
        )
      end
    end

    context "when .pco-release.config.yml specifies node_version as an integer" do
      it "wraps the command with nvm" do
        config =
          instance_double(
            Deployer::Config,
            version: "1.0.1",
            package_names: ["test"],
            upgrade_commands: {}
          )
        allow(config).to receive(:log)
        updater =
          described_class.new("repo", config: config, package_name: "test", repo: instance_double(Deployer::Repo))
        allow(File).to receive(:exist?).with(".pco-release.config.yml").and_return(true)
        allow(File).to receive(:exist?).with("package-lock.json").and_return(false)
        allow(YAML).to receive(:load_file).and_return("node_version" => 22)

        expect(updater.send(:with_node_version, updater.send(:upgrade_command))).to eq(
          "bash -lc '. \"$NVM_DIR/nvm.sh\" && nvm install 22 && nvm use 22 && yarn upgrade test@1.0.1'"
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

  describe "#run_upgrade_command" do
    it "passes the node-version-wrapped command to command_line.execute" do
      config =
        instance_double(
          Deployer::Config,
          version: "1.0.1",
          package_names: ["test"],
          upgrade_commands: {}
        )
      allow(config).to receive(:log)
      updater =
        described_class.new("repo", config: config, package_name: "test", repo: instance_double(Deployer::Repo))
      allow(File).to receive(:exist?).with(".pco-release.config.yml").and_return(true)
      allow(File).to receive(:exist?).with("package-lock.json").and_return(false)
      allow(YAML).to receive(:load_file).and_return("node_version" => "22")

      command_line = instance_double(Deployer::CommandLine)
      allow(Deployer::CommandLine).to receive(:new).and_return(command_line)
      expect(command_line).to receive(:execute).with(
        "bash -lc '. \"$NVM_DIR/nvm.sh\" && nvm install 22 && nvm use 22 && yarn upgrade test@1.0.1'",
        error_class: Deployer::UpgradeCommandFailure
      )

      updater.send(:run_upgrade_command)
    end

    it "passes the unwrapped command when no node_version is configured" do
      config =
        instance_double(
          Deployer::Config,
          version: "1.0.1",
          package_names: ["test"],
          upgrade_commands: {}
        )
      allow(config).to receive(:log)
      updater =
        described_class.new("repo", config: config, package_name: "test", repo: instance_double(Deployer::Repo))
      allow(File).to receive(:exist?).with(".pco-release.config.yml").and_return(true)
      allow(File).to receive(:exist?).with("package-lock.json").and_return(false)
      allow(YAML).to receive(:load_file).and_return({})

      command_line = instance_double(Deployer::CommandLine)
      allow(Deployer::CommandLine).to receive(:new).and_return(command_line)
      expect(command_line).to receive(:execute).with(
        "yarn upgrade test@1.0.1",
        error_class: Deployer::UpgradeCommandFailure
      )

      updater.send(:run_upgrade_command)
    end
  end
end
