# frozen_string_literal: true

module Gemini
  class Live
    # Helper class to build Live API messages
    class MessageBuilder
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

        # Build realtime input message (audio/video)
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

        # Build tool response message
        def tool_response(function_responses)
          {
            toolResponse: {
              functionResponses: function_responses.map do |resp|
                {
                  id: resp[:id],
                  name: resp[:name],
                  response: resp[:response]
                }
              end
            }
          }
        end

        private

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
