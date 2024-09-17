describe Deployer do
  let(:json_headers) { { "Content-Type" => "application/json" } }

  def stub_find_repos(repo_name)
    repos = [{ "id" => 11, "name" => repo_name, "archived" => false }]
    stub_request(
      :get,
      "https://api.github.com/orgs/planningcenter/repos?per_page=100"
    ).to_return(body: repos.to_json, headers: json_headers)
  end

  def stub_read_package_json(repo_name)
    stub_request(
      :get,
      "https://api.github.com/repos/planningcenter/#{repo_name}/contents/package.json"
    ).to_return(
      body: {
        content:
          Base64.encode64(
            '{"dependencies": {"@planningcenter/tapestry-react": "1.0.0"}}'
          )
      }.to_json,
      headers: json_headers
    )
  end

  def stub_clone_repo(suffix = "")
    allow(Open3).to receive(:capture3).with(
      "git clone https://oauth2:@github.com/planningcenter/topbar.git#{suffix}"
    ) do
      Dir.mkdir("topbar") unless Dir.exist?("topbar")
      ["", "", double(success?: true)]
    end
  end

  def stub_checkout_branch(
    branch_name = "pco-release--planningcenter-tapestry-react-1-0-1"
  )
    allow(Open3).to receive(:capture3).with(
      "git checkout #{branch_name} || git checkout -b #{branch_name}"
    ).and_return(["", "", double(success?: true)])
  end

  def stub_upgrade
    allow(Open3).to receive(:capture3).with(
      "yarn upgrade @planningcenter/tapestry-react@1.0.1"
    ).and_return(["", "", double(success?: true)])
  end

  def stub_commit_changes
    allow(Open3).to receive(:capture3).with(
      "git commit -am 'bump @planningcenter/tapestry-react to 1.0.1'"
    ).and_return(["", "", double(success?: true)])
  end

  def stub_push_changes(
    branch_name = "pco-release--planningcenter-tapestry-react-1-0-1"
  )
    allow(Open3).to receive(:capture3).with(
      "git push origin #{branch_name} -f"
    ).and_return(["", "", double(success?: true)])
  end

  def stub_create_pr
    stub_request(
      :post,
      "https://api.github.com/repos/planningcenter/topbar/pulls"
    ).to_return(body: { number: 1 }.to_json, headers: json_headers)
  end

  describe "#run" do
    it "updates the package in the specified repositories" do
      allow(Open3).to receive(:capture3).with(
        "npm install --silent"
      ).and_return(["", "", double(success?: true)])

      mock_file_parser = instance_double(Dependabot::NpmAndYarn::FileParser)
      allow(Dependabot::NpmAndYarn::FileParser).to receive(:new).and_return(
        mock_file_parser
      )
      allow(mock_file_parser).to receive(:parse).and_return(
        [
          instance_double(
            Dependabot::Dependency,
            top_level?: true,
            name: "@planningcenter/tapestry-react"
          )
        ]
      )
      allow(Dependabot::NpmAndYarn::UpdateChecker).to receive(:new).and_return(
        instance_double(
          Dependabot::NpmAndYarn::UpdateChecker,
          requirements_unlocked_or_can_be?: true,
          can_update?: true,
          updated_dependencies: [instance_double(Dependabot::Dependency)]
        )
      )
      stub_find_repos("topbar")
      stub_read_package_json("topbar")
      files = [
        instance_double(Dependabot::DependencyFile, name: "yarn.lock"),
        instance_double(Dependabot::DependencyFile, name: "package.json")
      ]
      allow(Dependabot::NpmAndYarn::FileFetcher).to receive(:new).and_return(
        instance_double(
          Dependabot::NpmAndYarn::FileFetcher,
          files: files,
          commit: ""
        )
      )
      allow(Dependabot::NpmAndYarn::FileUpdater).to receive(:new).and_return(
        instance_double(
          Dependabot::NpmAndYarn::FileUpdater,
          updated_dependency_files: files
        )
      )
      pull_request_creator = instance_double(Dependabot::PullRequestCreator)
      allow(Dependabot::PullRequestCreator).to receive(:new).with(
        hash_including(files: files)
      ).and_return(pull_request_creator)
      allow(pull_request_creator).to receive(:create).and_return(
        double(number: 1, html_url: "url")
      )

      config =
        Deployer::Config.new(
          github_token: "",
          owner: "planningcenter",
          package_name: "@planningcenter/tapestry-react",
          version: "1.0.1",
          allow_major: true
        )
      allow(config).to receive(:log)
      described_class.new(config).run
      expect(config).to have_received(:log).with(
        "Successfully updated @planningcenter/tapestry-react to 1.0.1 in topbar"
      )
      expect(pull_request_creator).to have_received(:create)
    end

    context "when specifying a merge" do
      it "uses the specified branch name" do
        stub_find_repos("topbar")
        stub_read_package_json("topbar")
        stub_clone_repo

        stub_checkout_branch("staging") # Unique branch name
        stub_upgrade
        stub_commit_changes
        stub_push_changes("staging") # Unique branch name

        config =
          Deployer::Config.new(
            github_token: "",
            owner: "planningcenter",
            package_name: "@planningcenter/tapestry-react",
            version: "1.0.1",
            change_method: "merge",
            branch_name: "staging", # Unique branch name
            allow_major: true
          )
        described_class.new(config).run
      end
    end
  end

  describe "#repos" do
    it "returns a list of repos that contain the package name" do
      stub_find_repos("test-repo")
      stub_read_package_json("test-repo")

      config =
        Deployer::Config.new(
          github_token: "",
          owner: "planningcenter",
          package_name: "@planningcenter/tapestry-react",
          version: "1.0.1"
        )
      expect(described_class.new(config).repos.map(&:name)).to eq(%w[test-repo])
    end
  end
end
