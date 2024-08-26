class Runner
  class Repos
    def initialize(
      client:,
      owner:,
      package_name:,
      automerge:,
      github_token:,
      version:,
      upgrade_commands:,
      only: []
    )
      @client = client
      @owner = owner
      @only = only
      @package_name = package_name
      @automerge = automerge
      @github_token = github_token
      @version = version
      @upgrade_commands = upgrade_commands
    end

    def find
      find_repos.map do |repo|
        Repo.new(
          repo["name"],
          automerge: automerge,
          owner: owner,
          github_token: github_token,
          package_name: package_name,
          version: version,
          upgrade_commands: upgrade_commands,
          client: client
        )
      end
    end

    private

    attr_reader :client,
                :owner,
                :only,
                :package_name,
                :automerge,
                :github_token,
                :version,
                :upgrade_commands

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

    IGNORED_REPOS = %w[
      account_center_integration
      audio-player-interface-ios
      AudioPlayerCache
      avatars
      check-ins-android
      check-ins-ios
      church-center-integration
      dashboard-appletv
      developers
      headcounts-react-native
      interfaces
      maybe_so
      MCTAudioPlayer
      MCTDataStore
      MCTJSON
      MCTReachability
      Music-Stand-Android
      music-stand-ios
      pco
      pco_api_oauth_example_sinatra_ruby
      pco_api_ruby
      pco-box
      pco-communication
      pco-ops
      PCOCocoa
      pcodashboard
      PCOKit
      PCOThemeKit
      pdf_helper
      planning-center-android-2
      planningcenter.github.io
      PlanningCenterCache
      post-to-sidekiq
      premailer-rails
      push-gateway
      ri_cal
      runt
      security
      services-ios
      superpico
      transposr
      upload
      upload-service-ios
      url_store
      web-maintenance
      push-gateway-client
      corsin
      pco-message-bus
      SocketRocket
      nginx-push-stream
      deadlock_retry
      Loper
      youtube-player-ios
      migrations
      raptor
      pco-staff-urls
      pubsub-push-stream
      whats-new-mobile
      slugger
      music-stand-react-native
      check-ins-desktop
      pusher-websocket-swift
      check-ins-app
      pcometadata
      webhooks
      pco-elasticsearch
      where-are-you-going
      resources-react-native
      ChurchCenterApp
      pco-platform-notifications
      metaphone3
      prince-serverless
      pco-api-engine
      reviewbot
      aci_delete_org
      on-site-interview
      iOS-App-Signing
      interview-pair-programming
      pco-embed-checker
      church_center_login_handshake
      pco-version-enforcer
      AbletonLinkIntegration
      pco-page-expired
      metronome-android
      pco-cross-storage
      yubikey
      MCTObjectStore
      PlanningCenterRouter-ios
      lottie-ios
      all-the-sidekiqs
      pco-cache
      pco-vscode-extension
      pco-email-signature
      pco-seeds
      pco-activity-feed
      pco-logger
      sam-aws-classifier
      pco-replica
      auroraops
      lambda-layer-imagemagick
      fllips-client
      subnetavailability
      balto-rubocop
      balto-eslint
      planning-center-zap
      sam-aws-ui
      signature
      support_toolbox
      spotinterrupt
      pco-gem
      react-native-image-viewer
      pco-scrubber
      serverless-slackbot
      Logger-ios
      incident-bot
      jolt
      jolt-example
      message-bus-to-jolt
      circleci-tools
      fllips
      imagemagick-aws-lambda-2
      pco-supersearch
      pco-session
      guru-algolia-sync
      rash
      plaid-ruby
      JSONAPI-ios
      jolt-client
      kiosk-conference-site
      js-api-client
      tapestry-react
      doxy-web
      topbar
      font-size
      mysql-parser
      CocoaPods-ios-specs
      balto-brakeman
      balto-prettier
      manualoauth
      PlanningCenterAuth-ios
      prerender_rails
      platform-online-schema-change
      codemirror-rails
      pco_api_oauth_example_slim_php
      pco_api_oauth_example_flask_python
      pco_api_oauth_example_node
      pco-my-church-center
      app-base
      whoisout
      twilio-webhook
      pollock-ios
      slack-points
      pico-arcade
      support-dashboard
      points-bot
      packages-test
      pco-station-backend
      message_bus_clean_up
      rds_proxy_helper
      browserslist-config
      .github
      pco-jolt
      version-enforcer-service
      build-notifier
      pco-trashable
      edna
      pco-raycast
      babel-preset
      balto-syntax_tree
      deleted-npm-packages
      plus-one-action
      staging-label-action
      minions
      repo-compliance-bot
      balto-utils
      balto-typescript
      pull-assign-action
      marketing-strapi-cms
      pending-checks-label-action
      pco-security-log
      add-ons-cli
      pco-add-on-demo
      activerecord-mysql-reconnect
      pco-annual-report
      pco-rollout
      design-hire-2023
      routing-key-counter
      shared-workflows
      pco-dev-blog
      gh-action-publish-internal-gem
      balto-discussions
      planning_center_password
      suspicious-email-bot
      stream-webhooks
      planning-center-pkce-sample-app
      spam-score-bot
      frontend-design-challenge
      flink-apps
      qa-bot
      sidekiq-runner
      slugger-test-make-app
      box-telemetry-service
      activerecord-retry-reads
      merge-groups-stream-exports
      pco-release-action
      ruby-lsp-pco-api
      all-the-flippers
      zendesk-help-center-redirects
      dependency-report
      gh-action-report-dependencies
      captains-log
      slack-ubiquiti-access
      puma-dev
      mailgun-webhooks
      module-federation-example
      rollup-plugin-module-federation
      vite-plugin-module-federation-rails
      module_federation_rails
      module-federation-builder
    ].freeze
  end
end
