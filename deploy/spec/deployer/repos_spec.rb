describe Deployer::Repos do
  let(:config) do
    Deployer::Config.new(
      github_token: "",
      owner: "planningcenter",
      package_names: ["test-pkg"],
      version: "1.2.7",
    )
  end
  let(:client) { instance_double(Octokit::Client, org_repos: [{ "name" => "test-repo" }]) }

  def stub_dependency(dependency = instance_double(Dependabot::Dependency, name: "test-pkg"))
    allow(Deployer::Repo::DependabotProxy).to receive(:new).with(
      "test-repo",
      config: anything,
      package_name: "test-pkg"
    ).and_return(instance_double(Deployer::Repo::DependabotProxy, dependency: dependency))
  end

  def stub_repo_fetching
    allow(client).to receive(:contents).with("planningcenter/test-repo", path: ".pco-release.config.yml", ref: "main").and_raise(Octokit::NotFound)
    allow(config).to receive(:client).and_return(client)
    stub_dependency
  end

  describe "#find" do
    it "returns a list of repos" do
      stub_repo_fetching
      repos = described_class.new(config).find
      expect(repos.map(&:name)).to eq(%w[test-repo])
    end

    it "excludes repos that are not in the only list" do
      stub_repo_fetching
      allow(config).to receive(:only).and_return(["other-repo"])
      repos = described_class.new(config).find
      expect(repos.map(&:name)).to eq([])
    end

    it "excludes repos that are in the exclude list" do
      stub_repo_fetching
      allow(config).to receive(:exclude).and_return(["test-repo"])
      repos = described_class.new(config).find
      expect(repos.map(&:name)).to eq([])
    end

    it "excludes repos that are archived" do
      stub_repo_fetching
      allow(client).to receive(:org_repos).and_return([{ "name" => "test-repo", "archived" => true }])
      repos = described_class.new(config).find
      expect(repos.map(&:name)).to eq([])
    end
  end
end
