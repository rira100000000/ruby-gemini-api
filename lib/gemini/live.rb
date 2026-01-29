# frozen_string_literal: true

require_relative "live/configuration"
require_relative "live/message_builder"
require_relative "live/connection"
require_relative "live/session"

module Gemini
  # Live API client for real-time audio/video/text interactions
  #
  # @example Basic text conversation
  #   client = Gemini::Client.new(api_key)
  #   session = client.live.connect(model: "gemini-2.0-flash-live-001")
  #
  #   session.on(:setup_complete) { puts "Connected!" }
  #   session.on(:text) { |text| puts "AI: #{text}" }
  #   session.on(:error) { |e| puts "Error: #{e}" }
  #
  #   session.send_text("Hello!")
  #   sleep 5
  #   session.close
  #
  # @example Audio conversation
  #   session = client.live.connect(
  #     model: "gemini-2.0-flash-live-001",
  #     response_modality: "AUDIO",
  #     voice_name: "Puck"
  #   )
  #
  #   session.on(:audio) { |data, mime| play_audio(data) }
  #   session.send_audio(pcm_data)  # 16-bit PCM, 16kHz, mono
  #
  # @example With block (auto-close)
  #   client.live.connect(model: "gemini-2.0-flash-live-001") do |session|
  #     session.on(:text) { |text| puts text }
  #     session.send_text("Hello!")
  #     sleep 5
  #   end  # session.close called automatically
  #
  class Live
    def initialize(client:)
      @client = client
    end

    # Establish a WebSocket connection and return a session
    #
    # @param model [String] Model to use (default: "gemini-2.0-flash-live-001")
    # @param response_modality [String] "TEXT" or "AUDIO" (default: "TEXT")
    # @param voice_name [String] Voice for audio responses (Puck, Charon, Kore, etc.)
    # @param system_instruction [String] System prompt
    # @param tools [Array] Tool definitions for function calling
    # @param context_window_compression [Hash] Compression settings for long sessions
    # @param session_resumption [Hash] Session resumption settings
    # @param automatic_activity_detection [Boolean] Enable/disable automatic VAD (default: true)
    # @param media_resolution [String] Media resolution setting
    # @param output_audio_transcription [Boolean] Enable audio transcription (default: false)
    # @yield [session] If block given, yields the session and closes it when block returns
    # @return [Gemini::Live::Session] The live session
    #
    def connect(
      model: Configuration::DEFAULT_MODEL,
      response_modality: "TEXT",
      voice_name: nil,
      system_instruction: nil,
      tools: nil,
      context_window_compression: nil,
      session_resumption: nil,
      automatic_activity_detection: true,
      media_resolution: nil,
      output_audio_transcription: false,
      &block
    )
      config = Configuration.new(
        model: model,
        response_modality: response_modality,
        voice_name: voice_name,
        system_instruction: system_instruction,
        tools: tools,
        context_window_compression: context_window_compression,
        session_resumption: session_resumption,
        automatic_activity_detection: automatic_activity_detection,
        media_resolution: media_resolution,
        output_audio_transcription: output_audio_transcription
      )

      session = Session.new(
        api_key: @client.api_key,
        configuration: config
      )

      if block_given?
        begin
          yield session
        ensure
          session.close
        end
      else
        session
      end
    end
  end
end
