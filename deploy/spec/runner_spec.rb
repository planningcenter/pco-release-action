describe "Runner" do
  describe "#repos" do
    it "returns a list of repos that contain the package name" do
      repos = [{ "id" => 11, "name" => "test-repo", "archived" => false }]
      stub_request(
        :get,
        "https://api.github.com/orgs/planningcenter/repos?per_page=100"
      ).to_return(body: repos)

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
        headers: {
          "Content-Type" => "application/json"
        }
      )

      expect(
        Runner
          .new(
            github_token: "",
            owner: "planningcenter",
            package_name: "@planningcenter/tapestry-react",
            version: "1.0.1"
          )
          .repos
          .map(&:name)
      ).to eq(%w[test-repo])
    end
  end
end
