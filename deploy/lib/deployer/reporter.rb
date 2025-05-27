require "shellwords"

class Deployer
  class Reporter
    def initialize(repos)
      @repos = repos
    end

    attr_reader :repos

    def to_json(_opts = {})
      as_json.to_json
    end

    def as_json(_opts = {})
      {
        failed_repos:
          failed_repos.map do |repo|
            { name: repo.name, message: repo.error_message }
          end,
        successful_repos:
          successful_repos.map do |repo|
            { name: repo.name, pr_number: repo.pr_number, pr_url: repo.pr_url }
          end
      }
    end

    def output_to_github
      json_data = to_json

      # Use GitHub Actions multiline environment variable format
      # This avoids issues with special characters
      File.open(ENV['GITHUB_ENV'], 'a') do |file|
        file.puts "results_json<<EOF"
        file.puts json_data
        file.puts "EOF"
      end
    end

    private

    def failed_repos
      repos.select(&:failure?)
    end

    def successful_repos
      repos.select(&:success?)
    end
  end
end
