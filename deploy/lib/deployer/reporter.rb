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
        system("echo #{Shellwords.escape(message)} >> $GITHUB_OUTPUT")
      end
      system("echo \"::set-output json={hi:\"bye\"}")
    end

    def fail_for_failed_repos!
      return unless failed_repos.any?

      raise "[PCO-Release]: Failed in the following repos:\n- #{failed_repos.map(&:name).join("\n- ")}"
    end

    private

    def output_messages
      ["json=\"#{to_json}\""]
    end

    def failed_repos
      repos.select(&:failure?)
    end

    def successful_repos
      repos.select(&:success?)
    end
  end
end
