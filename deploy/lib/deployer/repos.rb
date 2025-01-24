class Deployer
  class Repos
    def initialize(config)
      @config = config
    end

    def find
      repos = find_repos
      package_names.flat_map do |package_name|
        repos.map do |repo|
          Repo.new(repo["name"], package_name: package_name, config: config)
        end
      end.select(&:attempt_to_update?)
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

    def find_repos
      client.org_repos(owner).reject { |repo| repo["archived"] }
    end

    def filter_repos(repos)
      result = repos.select { |repo| only.include?(repo.name) } if only.any?
      result = result.reject { |repo| repo["archived"] }
      result.reject { |repo| config.exclude.include?(repo["name"]) }
    end
  end
end
