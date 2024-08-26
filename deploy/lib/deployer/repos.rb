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
        next false if IGNORED_REPOS.include?(repo["name"])
        next false if repo["archived"]

        response =
          client.contents("#{owner}/#{repo["name"]}", path: "package.json")
        contents = Base64.decode64(response.content)
        contents.include?(package_name)
      rescue Octokit::NotFound
        false
      end
    end
  end
end
