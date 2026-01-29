# frozen_string_literal: true

module Gemini
  class Live
    # Configuration class for Live API sessions
    class Configuration
      attr_accessor :model, :response_modality, :voice_name,
                    :system_instruction, :tools,
                    :context_window_compression, :session_resumption,
                    :automatic_activity_detection,
                    :media_resolution, :output_audio_transcription

      VALID_MODALITIES = %w[TEXT AUDIO].freeze
      VALID_VOICES = %w[Puck Charon Kore Fenrir Aoede Leda Orus Zephyr].freeze
      DEFAULT_MODEL = "gemini-2.5-flash-native-audio-preview-12-2025"

      def initialize(
        model: DEFAULT_MODEL,
        response_modality: "TEXT",
        voice_name: nil,
        system_instruction: nil,
        tools: nil,
        context_window_compression: nil,
        session_resumption: nil,
        automatic_activity_detection: true,
        media_resolution: nil,
        output_audio_transcription: false
      )
        @model = model
        @response_modality = validate_modality(response_modality)
        @voice_name = validate_voice(voice_name)
        @system_instruction = system_instruction
        @tools = tools
        @context_window_compression = context_window_compression
        @session_resumption = session_resumption
        @automatic_activity_detection = automatic_activity_detection
        @media_resolution = media_resolution
        @output_audio_transcription = output_audio_transcription
      end

      private

      def validate_modality(modality)
        modality = modality.to_s.upcase
        unless VALID_MODALITIES.include?(modality)
          raise ArgumentError, "Invalid modality: #{modality}. Must be one of: #{VALID_MODALITIES.join(', ')}"
        end
        modality
      end

      def validate_voice(voice)
        return nil if voice.nil?
        unless VALID_VOICES.include?(voice)
          raise ArgumentError, "Invalid voice: #{voice}. Must be one of: #{VALID_VOICES.join(', ')}"
        end
        voice
      end
    end
  end
end
