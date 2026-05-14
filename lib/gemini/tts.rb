module Gemini
  class TTS
    DEFAULT_MODEL = "gemini-2.5-flash-preview-tts".freeze

    # 30 prebuilt voice names available for the prebuiltVoiceConfig
    VOICES = %w[
      Zephyr Puck Charon Kore Fenrir Leda Orus Aoede Callirrhoe Autonoe
      Enceladus Iapetus Umbriel Algieba Despina Erinome Algenib Rasalgethi
      Laomedeia Achernar Alnilam Schedar Gacrux Pulcherrima Achird
      Zubenelgenubi Vindemiatrix Sadachbia Sadaltager Sulafat
    ].freeze

    def initialize(client:)
      @client = client
    end

    # Generate speech audio from text.
    #
    # text: prompt String (use style cues / bracket tags like [excited] for control,
    #       or "Speaker 1: ... Speaker 2: ..." for multi-speaker).
    # voice: a single voice name (prebuiltVoiceConfig). Mutually exclusive with multi_speaker.
    # multi_speaker: Array of { speaker:, voice: } Hashes for multi-speaker output.
    # model: TTS preview model name. Defaults to gemini-2.5-flash-preview-tts.
    # speech_config: raw speechConfig Hash override (skips voice/multi_speaker handling).
    def generate(text, voice: nil, multi_speaker: nil, model: DEFAULT_MODEL,
                 speech_config: nil, **parameters)
      raise ArgumentError, "text is required" if text.nil? || text.to_s.empty?
      if voice && multi_speaker
        raise ArgumentError, "voice and multi_speaker are mutually exclusive"
      end

      resolved_speech_config = speech_config || build_speech_config(voice: voice, multi_speaker: multi_speaker)
      raise ArgumentError, "voice, multi_speaker, or speech_config is required" unless resolved_speech_config

      payload = {
        contents: [{ parts: [{ text: text }] }],
        generationConfig: {
          responseModalities: ["AUDIO"],
          speechConfig: resolved_speech_config
        }
      }

      payload.merge!(parameters) if parameters && !parameters.empty?

      response = @client.json_post(
        path: "models/#{normalize_model(model)}:generateContent",
        parameters: payload
      )
      Gemini::Response.new(response)
    end

    private

    def build_speech_config(voice:, multi_speaker:)
      if multi_speaker
        speaker_voice_configs = multi_speaker.map do |entry|
          speaker = entry[:speaker] || entry["speaker"]
          v = entry[:voice] || entry["voice"]
          raise ArgumentError, "multi_speaker entries require :speaker and :voice" unless speaker && v
          validate_voice!(v)
          {
            speaker: speaker,
            voiceConfig: { prebuiltVoiceConfig: { voiceName: v } }
          }
        end
        { multiSpeakerVoiceConfig: { speakerVoiceConfigs: speaker_voice_configs } }
      elsif voice
        validate_voice!(voice)
        { voiceConfig: { prebuiltVoiceConfig: { voiceName: voice } } }
      end
    end

    def validate_voice!(voice)
      return if VOICES.include?(voice.to_s)
      raise ArgumentError, "Unknown voice '#{voice}'. Available voices: #{VOICES.join(', ')}"
    end

    def normalize_model(model)
      model_str = model.to_s
      model_str.start_with?("models/") ? model_str.delete_prefix("models/") : model_str
    end
  end
end
