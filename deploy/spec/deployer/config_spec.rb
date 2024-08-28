describe Deployer::Config do
  it "keeps track of the config options for a run" do
    config =
      Deployer::Config.new(
        github_token: "",
        owner: "planningcenter",
        package_name: "@planningcenter/tapestry-react",
        version: "1.0.1"
      )

    expect(config.github_token).to eq("")
    expect(config.owner).to eq("planningcenter")
    expect(config.package_name).to eq("@planningcenter/tapestry-react")
    expect(config.version).to eq("1.0.1")
    expect(config.automerge).to eq(false)
    expect(config.only).to eq([])
    expect(config.upgrade_commands).to eq({})
    expect(config.include).to eq([])
    expect(config.exclude).to eq([])
    expect(config.change_method).to eq("pr")
    expect(config.branch_name).to eq("main")
  end
end
