describe Deployer::Reporter do
  let(:failed_repo) do
    instance_double(
      Deployer::Repo,
      name: "test",
      error_message: "Missing permissions.",
      failure?: true,
      success?: false
    )
  end
  let(:successful_repo) do
    instance_double(
      Deployer::Repo,
      name: "test2",
      pr_number: 127,
      pr_url: "http://github.com/org/repo/pull/127",
      failure?: false,
      success?: true
    )
  end

  describe "#to_json" do
    it "returns a json representation of the report" do
      report = described_class.new([failed_repo, successful_repo])

      expect(report.to_json).to eq(
        {
          failed_repos: [{ name: "test", message: "Missing permissions." }],
          successful_repos: [
            {
              name: "test2",
              pr_number: 127,
              pr_url: "http://github.com/org/repo/pull/127"
            }
          ]
        }.to_json
      )
    end
  end

  describe "#output_to_github" do
    let(:temp_file) { Tempfile.new('github_env') }

    before do
      ENV['GITHUB_ENV'] = temp_file.path
    end

    after do
      temp_file.close
      temp_file.unlink
    end

    it "writes JSON data to GITHUB_ENV using multiline format" do
      report = described_class.new([failed_repo, successful_repo])

      report.output_to_github

      env_content = File.read(temp_file.path)
      expect(env_content).to eq("results_json<<EOF\n#{report.to_json}\nEOF\n")
    end

    it "handles JSON with special characters" do
      special_repo = instance_double(
        Deployer::Repo,
        name: "test-with-`backticks`-and-'quotes'",
        error_message: "Error with `backticks` and \"quotes\"",
        failure?: true,
        success?: false
      )

      report = described_class.new([special_repo])

      expect { report.output_to_github }.not_to raise_error

      env_content = File.read(temp_file.path)
      expect(env_content).to include(special_repo.name)
      expect(env_content).to include("Error with `backticks` and \\\"quotes\\\"")
    end
  end
end
