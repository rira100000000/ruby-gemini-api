# frozen_string_literal: true

RSpec.describe Gemini::Live::Configuration do
  describe "#initialize" do
    context "with default values" do
      subject(:config) { described_class.new }

      it "sets default model" do
        expect(config.model).to eq("gemini-2.5-flash-native-audio-preview-12-2025")
      end

      it "sets default response modality to TEXT" do
        expect(config.response_modality).to eq("TEXT")
      end

      it "sets automatic_activity_detection to true" do
        expect(config.automatic_activity_detection).to be true
      end

      it "sets voice_name to nil" do
        expect(config.voice_name).to be_nil
      end
    end

    context "with valid modalities" do
      it "accepts TEXT modality" do
        config = described_class.new(response_modality: "TEXT")
        expect(config.response_modality).to eq("TEXT")
      end

      it "accepts AUDIO modality" do
        config = described_class.new(response_modality: "AUDIO")
        expect(config.response_modality).to eq("AUDIO")
      end

      it "accepts lowercase modality and converts to uppercase" do
        config = described_class.new(response_modality: "text")
        expect(config.response_modality).to eq("TEXT")
      end

      it "accepts symbol modality" do
        config = described_class.new(response_modality: :audio)
        expect(config.response_modality).to eq("AUDIO")
      end
    end

    context "with invalid modality" do
      it "raises ArgumentError" do
        expect {
          described_class.new(response_modality: "INVALID")
        }.to raise_error(ArgumentError, /Invalid modality/)
      end
    end

    context "with valid voice names" do
      Gemini::Live::Configuration::VALID_VOICES.each do |voice|
        it "accepts #{voice}" do
          config = described_class.new(voice_name: voice)
          expect(config.voice_name).to eq(voice)
        end
      end
    end

    context "with invalid voice name" do
      it "raises ArgumentError" do
        expect {
          described_class.new(voice_name: "InvalidVoice")
        }.to raise_error(ArgumentError, /Invalid voice/)
      end
    end

    context "with all options" do
      subject(:config) do
        described_class.new(
          model: "gemini-2.5-flash-native-audio-preview-12-2025",
          response_modality: "AUDIO",
          voice_name: "Puck",
          system_instruction: "You are a helpful assistant.",
          tools: [{ google_search: {} }],
          context_window_compression: { slidingWindow: { targetTokens: 10000 } },
          session_resumption: { handle: "token123" },
          automatic_activity_detection: false,
          media_resolution: "MEDIA_RESOLUTION_LOW",
          output_audio_transcription: true
        )
      end

      it "sets all values correctly" do
        expect(config.model).to eq("gemini-2.5-flash-native-audio-preview-12-2025")
        expect(config.response_modality).to eq("AUDIO")
        expect(config.voice_name).to eq("Puck")
        expect(config.system_instruction).to eq("You are a helpful assistant.")
        expect(config.tools).to eq([{ google_search: {} }])
        expect(config.context_window_compression).to eq({ slidingWindow: { targetTokens: 10000 } })
        expect(config.session_resumption).to eq({ handle: "token123" })
        expect(config.automatic_activity_detection).to be false
        expect(config.media_resolution).to eq("MEDIA_RESOLUTION_LOW")
        expect(config.output_audio_transcription).to be true
      end
    end
  end
end
