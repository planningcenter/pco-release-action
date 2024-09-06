require "shellwords"

class Deployer
  class Reporter
    def initialize(repos)
      @repos = repos
    end

    attr_reader :repos

    def to_json(_opts = {})
      {
        failed_repos:
          failed_repos.map do |repo|
            { name: repo.name, message: repo.error_message }
          end,
        successful_repos:
          successful_repos.map do |repo|
            { name: repo.name, pr_number: repo.pr_number, pr_url: repo.pr_url }
          end
      }.to_json
    end

    def output_to_github
      output_messages.each do |message|
        # I have tried for hours to get this to go to the output, but it never works.  Using env instead.
        system("echo #{Shellwords.escape(message)} >> $GITHUB_ENV")
      end
    end

    private

    def output_messages
      ["results_json=#{to_json}"]
    end

    def failed_repos
      repos.select(&:failure?)
    end

    def successful_repos
      repos.select(&:success?)
    end
  end
end
