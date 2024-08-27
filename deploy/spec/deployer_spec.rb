describe Deployer do
  let(:json_headers) { { "Content-Type" => "application/json" } }

  describe "#run" do
    it "updates the package in the specified repositories" do
      repos = [{ "id" => 11, "name" => "topbar", "archived" => false }]
      stub_request(
        :get,
        "https://api.github.com/orgs/planningcenter/repos?per_page=100"
      ).to_return(body: repos.to_json, headers: json_headers)
      stub_request(
        :get,
        "https://api.github.com/repos/planningcenter/topbar/contents/package.json"
      ).to_return(
        body: {
          content:
            Base64.encode64(
              '{"dependencies": {"@planningcenter/tapestry-react": "1.0.0"}}'
            )
        }.to_json,
        headers: json_headers
      )

      allow(Open3).to receive(:capture3).with(
        "git clone https://:x-oauth-basic@github.com/planningcenter/topbar.git --depth=1"
      ) do
        Dir.mkdir("topbar") unless Dir.exist?("topbar")
        ["", "", double(success?: true)]
      end
      allow(Open3).to receive(:capture3).with(
        "git checkout -b pco-release--planningcenter-tapestry-react-1-0-1"
      ).and_return(["", "", double(success?: true)])
      allow(Open3).to receive(:capture3).with(
        "yarn upgrade @planningcenter/tapestry-react@1.0.1"
      ).and_return(["", "", double(success?: true)])
      allow(Open3).to receive(:capture3).with(
        "git commit -am 'bump @planningcenter/tapestry-react to 1.0.1'"
      ).and_return(["", "", double(success?: true)])
      allow(Open3).to receive(:capture3).with(
        "git push origin pco-release--planningcenter-tapestry-react-1-0-1 -f"
      ).and_return(["", "", double(success?: true)])

      stub_request(
        :post,
        "https://api.github.com/repos/planningcenter/topbar/pulls"
      ).to_return(body: { number: 1 }.to_json, headers: json_headers)

      config =
        Deployer::Config.new(
          github_token: "",
          owner: "planningcenter",
          package_name: "@planningcenter/tapestry-react",
          version: "1.0.1"
        )
      allow(config).to receive(:log)
      described_class.new(config).run
      expect(config).to have_received(:log).with(
        "Successfully updated @planningcenter/tapestry-react to 1.0.1 in topbar (https://github.com/planningcenter/topbar/pull/1)"
      )
    end
  end

  describe "#repos" do
    it "returns a list of repos that contain the package name" do
      repos = [{ "id" => 11, "name" => "test-repo", "archived" => false }]
      stub_request(
        :get,
        "https://api.github.com/orgs/planningcenter/repos?per_page=100"
      ).to_return(body: repos.to_json, headers: json_headers)

      stub_request(
        :get,
        "https://api.github.com/repos/planningcenter/test-repo/contents/package.json"
      ).to_return(
        body: {
          content:
            Base64.encode64(
              '{"dependencies": {"@planningcenter/tapestry-react": "1.0.0"}}'
            )
        }.to_json,
        headers: json_headers
      )

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
