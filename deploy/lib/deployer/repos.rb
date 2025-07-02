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
      end.reject(&:exclude_from_reporting?)
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
  end
end
