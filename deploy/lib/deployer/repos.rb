class Deployer
  class Repos
    def initialize(config)
      @config = config
    end

    def find
      package_names.flat_map do |package_name|
        find_repos(package_name).map do |repo|
          Repo.new(repo["name"], package_name: package_name, config: config)
        end
      end
    end

    private

    attr_reader :config

    def owner
      config.owner
    end

    def package_names
      config.package_names
    end

    def only
      config.only
    end

    def client
      config.client
    end

    def find_repos(package_name)
      repos = client.org_repos(owner)
      return repos.select { |repo| only.include?(repo.name) } if only.any?

      select_packages_that_consume_package(repos, package_name)
    end

    def select_packages_that_consume_package(repos, package_name)
      repos.select do |repo|
        next false if repo["archived"]
        next true if config.include.include?(repo["name"])
        next false if config.exclude.include?(repo["name"])

        consumer_of_package?(repo, package_name)
      end
    end

    def consumer_of_package?(repo, package_name)
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
