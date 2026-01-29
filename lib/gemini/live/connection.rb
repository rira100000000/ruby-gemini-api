# frozen_string_literal: true

require "websocket-client-simple"
require "json"

module Gemini
  class Live
    # WebSocket connection manager for Live API
    class Connection
      WEBSOCKET_BASE_URL = "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent"

      attr_reader :connected

      def initialize(api_key:, on_message:, on_open:, on_error:, on_close:)
        @api_key = api_key
        @on_message = on_message
        @on_open = on_open
        @on_error = on_error
        @on_close = on_close
        @ws = nil
        @connected = false
        @mutex = Mutex.new
      end

      def connect
        url = "#{WEBSOCKET_BASE_URL}?key=#{@api_key}"

        # Store callbacks in local variables for closure
        on_message_callback = @on_message
        on_open_callback = @on_open
        on_error_callback = @on_error
        on_close_callback = @on_close
        connection = self

        @ws = WebSocket::Client::Simple.connect(url) do |ws|
          ws.on :open do
            connection.instance_variable_set(:@connected, true)
            on_open_callback.call if on_open_callback
          end

          ws.on :message do |msg|
            on_message_callback.call(msg.data) if on_message_callback
          end

          ws.on :error do |e|
            on_error_callback.call(e) if on_error_callback
          end

          ws.on :close do |e|
            connection.instance_variable_set(:@connected, false)
            code = e.respond_to?(:code) ? e.code : nil
            reason = e.respond_to?(:reason) ? e.reason : nil
            on_close_callback.call(code, reason) if on_close_callback
          end
        end

        self
      end

      def send(data)
        return false unless @ws && @connected

        @mutex.synchronize do
          json_data = data.is_a?(String) ? data : data.to_json
          @ws.send(json_data)
        end
        true
      rescue StandardError => e
        @on_error&.call(e)
        false
      end

      def close
        @ws&.close
        @connected = false
      end

      def connected?
        @connected && @ws && !@ws.closed?
      end
    end
  end
end
