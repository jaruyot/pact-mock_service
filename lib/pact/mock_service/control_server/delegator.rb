# Delegates the incoming request that was sent to the control server
# to the underlying MockService
# if the X-Pact-Consumer and X-Pact-Provider headers match
# the consumer and provider for this MockService.

module Pact
  module MockService
    module ControlServer

      class Delegator

        # Idle timouet 5400 seconds = 1 hour 30 mins
        APP_IDLE_TIMEOUT_SECONDS = 5400.freeze

        HTTP_X_PACT_CONSUMER = 'HTTP_X_PACT_CONSUMER'.freeze
        HTTP_X_PACT_PROVIDER = 'HTTP_X_PACT_PROVIDER'.freeze
        PACT_MOCK_SERVICE_HEADER = {'HTTP_X_PACT_MOCK_SERVICE' => 'true'}.freeze
        NOT_FOUND_RESPONSE = [404, {}, []].freeze

        def initialize app, consumer_name, provider_name
          @app = app
          @consumer_name = consumer_name
          @provider_name = provider_name
        end

        def call env
          is_same_povider_and_consumer = consumer_and_provider_headers_match?(env)
          
          app_last_call = @app.get_last_call
          app_is_idle = check_if_app_is_idle?(app_last_call)

          return NOT_FOUND_RESPONSE unless is_same_povider_and_consumer || app_is_idle
          if !is_same_povider_and_consumer && app_is_idle
              puts "The mock server for provider #{@provider_name} has not been called for #{(Time.now - app_last_call).round()} seconds. Replacing it with provider #{env[HTTP_X_PACT_PROVIDER]}"
              @consumer_name = env[HTTP_X_PACT_CONSUMER]
              @provider_name = env[HTTP_X_PACT_PROVIDER]
          end

          delegate env
        end

        def shutdown
          @app.shutdown
        end

        private

        def consumer_and_provider_headers_match? env
          env[HTTP_X_PACT_CONSUMER] == @consumer_name && env[HTTP_X_PACT_PROVIDER] == @provider_name
        end

        def check_if_app_is_idle? last_call
          !last_call.nil? && Time.now - last_call > APP_IDLE_TIMEOUT_SECONDS
        end

        def delegate env
          @app.call(env.merge(PACT_MOCK_SERVICE_HEADER))
        end
      end
    end
  end
end
