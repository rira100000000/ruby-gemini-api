# frozen_string_literal: true

require "json"
require "base64"

module Gemini
  class Live
    # Live API session manager
    class Session
      attr_reader :configuration, :last_resumption_token, :usage_metadata

      def initialize(api_key:, configuration:)
        @api_key = api_key
        @configuration = configuration
        @event_handlers = Hash.new { |h, k| h[k] = [] }
        @connected = false
        @setup_complete = false
        @last_resumption_token = nil
        @usage_metadata = nil
        @connection = nil

        setup_connection
      end

      # Register event handler
      # Supported events:
      #   :setup_complete - Session setup completed
      #   :text           - Text response received (text)
      #   :audio          - Audio data received (base64_data, mime_type)
      #   :data           - Other inline data received (base64_data, mime_type)
      #   :tool_call      - Tool call requested (function_calls)
      #   :interrupted    - User interrupted the model
      #   :turn_complete  - Model turn completed
      #   :generation_complete - Generation completed
      #   :usage_metadata - Token usage info received (metadata)
      #   :session_resumption - Session resumption token updated (update)
      #   :go_away        - Connection will close soon (info)
      #   :error          - Error occurred (error)
      #   :close          - Connection closed (code, reason)
      def on(event, &block)
        @event_handlers[event.to_sym] << block
        self
      end

      # Send text message
      def send_text(text, turn_complete: true)
        ensure_setup_complete!
        message = MessageBuilder.client_content(
          text: text,
          turn_complete: turn_complete
        )
        @connection.send(message)
      end

      # Send audio data (Base64 encoded PCM)
      def send_audio(audio_data, mime_type: "audio/pcm;rate=16000")
        ensure_setup_complete!
        encoded_data = audio_data.is_a?(String) && audio_data.encoding == Encoding::BINARY ?
          Base64.strict_encode64(audio_data) : audio_data
        message = MessageBuilder.realtime_input(
          audio_data: encoded_data,
          mime_type: mime_type
        )
        @connection.send(message)
      end

      # Send video/image data (Base64 encoded)
      def send_video(image_data, mime_type: "image/jpeg")
        ensure_setup_complete!
        encoded_data = image_data.is_a?(String) && image_data.encoding == Encoding::BINARY ?
          Base64.strict_encode64(image_data) : image_data
        message = MessageBuilder.realtime_input(
          video_data: encoded_data,
          mime_type: mime_type
        )
        @connection.send(message)
      end

      # Send tool response
      def send_tool_response(function_responses)
        ensure_setup_complete!
        message = MessageBuilder.tool_response(function_responses)
        @connection.send(message)
      end

      # Manual VAD control - signal activity start
      def activity_start
        ensure_setup_complete!
        @connection.send(MessageBuilder.activity_start)
      end

      # Manual VAD control - signal activity end
      def activity_end
        ensure_setup_complete!
        @connection.send(MessageBuilder.activity_end)
      end

      # Close the session
      def close
        @connection&.close
        @connected = false
        @setup_complete = false
      end

      def connected?
        @connected && @connection&.connected?
      end

      def setup_complete?
        @setup_complete
      end

      private

      def setup_connection
        @connection = Connection.new(
          api_key: @api_key,
          on_message: method(:handle_message),
          on_open: method(:handle_open),
          on_error: method(:handle_error),
          on_close: method(:handle_close)
        )
        @connection.connect
        @connected = true
      end

      def handle_open
        # Send setup message immediately after connection opens
        setup_message = MessageBuilder.setup(@configuration)
        @connection.send(setup_message)
      end

      def handle_message(data)
        parsed = JSON.parse(data, symbolize_names: true)

        if parsed[:setupComplete]
          @setup_complete = true
          emit(:setup_complete)
        elsif parsed[:serverContent]
          handle_server_content(parsed[:serverContent])
        elsif parsed[:toolCall]
          emit(:tool_call, parsed[:toolCall][:functionCalls])
        elsif parsed[:usageMetadata]
          @usage_metadata = parsed[:usageMetadata]
          emit(:usage_metadata, parsed[:usageMetadata])
        elsif parsed[:sessionResumptionUpdate]
          handle_session_resumption(parsed[:sessionResumptionUpdate])
        elsif parsed[:goAway]
          emit(:go_away, parsed[:goAway])
        end
      rescue JSON::ParserError => e
        emit(:error, e)
      end

      def handle_server_content(content)
        # Check for interruption
        if content[:interrupted]
          emit(:interrupted)
          return
        end

        # Check for generation complete
        if content[:generationComplete]
          emit(:generation_complete)
        end

        # Process model turn
        model_turn = content[:modelTurn]
        if model_turn
          model_turn[:parts]&.each do |part|
            if part[:text]
              emit(:text, part[:text])
            elsif part[:inlineData]
              inline = part[:inlineData]
              if inline[:mimeType]&.start_with?("audio/")
                emit(:audio, inline[:data], inline[:mimeType])
              else
                emit(:data, inline[:data], inline[:mimeType])
              end
            end
          end
        end

        # Check for turn complete
        emit(:turn_complete) if content[:turnComplete]
      end

      def handle_session_resumption(update)
        @last_resumption_token = update[:newHandle]
        emit(:session_resumption, update)
      end

      def handle_error(error)
        emit(:error, error)
      end

      def handle_close(code, reason)
        @connected = false
        @setup_complete = false
        emit(:close, code, reason)
      end

      def emit(event, *args)
        @event_handlers[event].each { |handler| handler.call(*args) }
      end

      def ensure_setup_complete!
        raise Gemini::Error, "Session setup not complete. Wait for :setup_complete event." unless @setup_complete
      end
    end
  end
end
