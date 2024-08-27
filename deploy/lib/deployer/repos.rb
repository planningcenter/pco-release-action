class Deployer
  class Repos
    def initialize(config)
      @config = config
    end

    def find
      find_repos.map { |repo| Repo.new(repo["name"], config: config) }
    end

    private

    attr_reader :config

    def owner
      config.owner
    end

    def package_name
      config.package_name
    end

    def only
      config.only
    end

    def client
      config.client
    end

    def find_repos
      repos = client.org_repos(owner)
      return repos.select { |repo| only.include?(repo.name) } if only.any?

      select_packages_that_consume_package(repos)
    end

    def select_packages_that_consume_package(repos)
      repos.select do |repo|
        next false if repo["archived"]
        next true if config.include.include?(repo["name"])
        next false if config.exclude.include?(repo["name"])

        consumer_of_package?(repo)
      end
    end

    def consumer_of_package?(repo)
      response =
        client.contents("#{owner}/#{repo["name"]}", path: "package.json")
      contents = JSON.parse(Base64.decode64(response.content))
      contents["dependencies"]&.key?(package_name) ||
        contents["devDependencies"]&.key?(package_name)
    rescue Octokit::NotFound
      false
    end
  end
end
