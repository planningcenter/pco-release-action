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

  describe "#output_messages" do
    it "returns the code to set up the proper outputs" do
      report = described_class.new([failed_repo, successful_repo])

      expect(report.send(:output_messages)).to eq(
        ["results_json=#{report.to_json}"]
      )
    end
  end
end
