# frozen_string_literal: true

module Gemini
  class Live
    # Helper class to build Live API messages
    class MessageBuilder
      VALID_SCHEDULING = %w[INTERRUPT WHEN_IDLE SILENT].freeze

      class << self
        # Build setup message from configuration
        def setup(config)
          message = {
            setup: {
              model: normalize_model_name(config.model)
            }
          }

          generation_config = build_generation_config(config)
          message[:setup][:generationConfig] = generation_config unless generation_config.empty?

          # System instruction
          if config.system_instruction
            message[:setup][:systemInstruction] = {
              parts: [{ text: config.system_instruction }]
            }
          end

          # Tools configuration
          message[:setup][:tools] = config.tools if config.tools

          # Context window compression
          if config.context_window_compression
            message[:setup][:contextWindowCompression] = config.context_window_compression
          end

          # Session resumption
          if config.session_resumption
            message[:setup][:sessionResumption] = config.session_resumption
          end

          # VAD (Voice Activity Detection) settings
          unless config.automatic_activity_detection
            message[:setup][:realtimeInputConfig] = {
              automaticActivityDetection: {
                disabled: true
              }
            }
          end

          message
        end

        # Build client content message (text)
        def client_content(text:, turn_complete: true, role: "user")
          {
            clientContent: {
              turns: [
                {
                  role: role,
                  parts: [{ text: text }]
                }
              ],
              turnComplete: turn_complete
            }
          }
        end

        # Build client content with multiple parts
        def client_content_parts(parts:, turn_complete: true, role: "user")
          {
            clientContent: {
              turns: [
                {
                  role: role,
                  parts: parts
                }
              ],
              turnComplete: turn_complete
            }
          }
        end

        # Build realtime input message (audio/video) using the legacy
        # mediaChunks field. NOTE: mediaChunks is deprecated by the API in
        # favor of the dedicated audio/video fields built by realtime_audio
        # and realtime_video. Kept for backward compatibility with older
        # Live models that still accept it.
        def realtime_input(audio_data: nil, video_data: nil, mime_type:)
          data = audio_data || video_data
          {
            realtimeInput: {
              mediaChunks: [
                {
                  mimeType: mime_type,
                  data: data
                }
              ]
            }
          }
        end

        # Build a realtime text input message. This is the universal
        # text-input form for the Live API and is required by newer Live
        # models such as gemini-3.1-flash-live-preview, which reject the
        # turn-based clientContent payload.
        def realtime_text(text)
          { realtimeInput: { text: text.to_s } }
        end

        # Build activity start message (for manual VAD)
        def activity_start
          {
            realtimeInput: {
              activityStart: {}
            }
          }
        end

        # Build activity end message (for manual VAD)
        def activity_end
          {
            realtimeInput: {
              activityEnd: {}
            }
          }
        end

        # Build tool response message.
        #
        # Each function response hash supports:
        #   :id       - The function call id from the server
        #   :name     - The function name
        #   :response - The function result (Hash or scalar). When using
        #               NON_BLOCKING (async) function calls, include
        #               `scheduling: "INTERRUPT" | "WHEN_IDLE" | "SILENT"`
        #               inside the response hash.
        #   :scheduling - (optional) Top-level shortcut. When provided,
        #                 it is merged into the response hash as
        #                 `response[:scheduling]`. Accepts Symbol or String.
        #
        # Raises ArgumentError if scheduling is not one of the valid values.
        def tool_response(function_responses)
          {
            toolResponse: {
              functionResponses: function_responses.map { |resp| build_function_response(resp) }
            }
          }
        end

        private

        def build_function_response(resp)
          response_payload =
            case resp[:response]
            when Hash then resp[:response].dup
            when nil  then {}
            else { result: resp[:response] }
            end

          if (top_level_scheduling = resp[:scheduling])
            response_payload[:scheduling] = normalize_scheduling(top_level_scheduling)
          elsif (sched = response_payload[:scheduling] || response_payload["scheduling"])
            normalized = normalize_scheduling(sched)
            response_payload.delete("scheduling")
            response_payload[:scheduling] = normalized
          end

          { id: resp[:id], name: resp[:name], response: response_payload }
        end

        def normalize_scheduling(value)
          value_str = value.to_s.upcase
          unless VALID_SCHEDULING.include?(value_str)
            raise ArgumentError,
                  "scheduling must be one of: #{VALID_SCHEDULING.join(', ')} (got #{value.inspect})"
          end
          value_str
        end


        def normalize_model_name(model)
          model.start_with?("models/") ? model : "models/#{model}"
        end

        def build_generation_config(config)
          generation_config = {}

          # Response modality
          generation_config[:responseModalities] = [config.response_modality]

          # Speech/Voice configuration for AUDIO modality
          if config.response_modality == "AUDIO" && config.voice_name
            generation_config[:speechConfig] = {
              voiceConfig: {
                prebuiltVoiceConfig: {
                  voiceName: config.voice_name
                }
              }
            }
          end

          # Media resolution
          if config.media_resolution
            generation_config[:mediaResolution] = config.media_resolution
          end

          # Output audio transcription
          if config.output_audio_transcription
            generation_config[:outputAudioTranscription] = {}
          end

          generation_config
        end
      end
    end
  end
end
