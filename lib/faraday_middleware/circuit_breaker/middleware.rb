require 'faraday'
require 'stoplight'
require 'faraday_middleware/circuit_breaker/option_set'

module FaradayMiddleware
  module CircuitBreaker
    class Middleware < Faraday::Middleware

      def initialize(app, options = {})
        super(app)
        assert_valid_options!(options)

        @option_set = OptionSet.new(options)

        setup_notifiers
      end

      def call(env)
        Stoplight(env.url.to_s) do
          @app.call(env)
        end
        .with_timeout(option_set.timeout)
        .with_threshold(option_set.threshold)
        .with_fallback { |e| option_set.fallback.call(env, e) }
        .run
      end

      private

      attr_reader :option_set

      def setup_notifiers
        option_set.notifiers.each do |notifier, value|
          case notifier.to_sym
          when :logger
            Stoplight::Light.default_notifiers += [Stoplight::Notifier::Logger.new(value)]
          when :honeybadger
            Stoplight::Light.default_notifiers += [Stoplight::Notifier::Honeybadger.new(value)]
          when :hip_chat
            Stoplight::Light.default_notifiers += [Stoplight::Notifier::HipChat.new(value[:client], value[:room])]
          when :slack
            Stoplight::Light.default_notifiers += [Stoplight::Notifier::Slack.new(value)]
          when :bugsnag
            Stoplight::Light.default_notifiers += [Stoplight::Notifier::Bugsnag.new(value)]
          end
        end
      end

      def assert_valid_options!(options)
        OptionSet.validate!(options)
      end

    end
  end
end