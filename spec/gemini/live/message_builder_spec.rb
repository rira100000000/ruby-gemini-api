# frozen_string_literal: true

RSpec.describe Gemini::Live::MessageBuilder do
  describe ".setup" do
    context "with minimal configuration" do
      let(:config) { Gemini::Live::Configuration.new }

      it "builds correct setup message" do
        message = described_class.setup(config)

        expect(message[:setup][:model]).to eq("models/gemini-2.5-flash-live-preview")
        expect(message[:setup][:generationConfig][:responseModalities]).to eq(["TEXT"])
      end
    end

    context "with AUDIO modality and voice" do
      let(:config) do
        Gemini::Live::Configuration.new(
          response_modality: "AUDIO",
          voice_name: "Puck"
        )
      end

      it "includes speech config" do
        message = described_class.setup(config)

        expect(message[:setup][:generationConfig][:responseModalities]).to eq(["AUDIO"])
        expect(message[:setup][:generationConfig][:speechConfig]).to eq({
          voiceConfig: {
            prebuiltVoiceConfig: {
              voiceName: "Puck"
            }
          }
        })
      end
    end

    context "with system instruction" do
      let(:config) do
        Gemini::Live::Configuration.new(
          system_instruction: "You are a helpful assistant."
        )
      end

      it "includes system instruction" do
        message = described_class.setup(config)

        expect(message[:setup][:systemInstruction]).to eq({
          parts: [{ text: "You are a helpful assistant." }]
        })
      end
    end

    context "with tools" do
      let(:config) do
        Gemini::Live::Configuration.new(
          tools: [{ google_search: {} }]
        )
      end

      it "includes tools" do
        message = described_class.setup(config)

        expect(message[:setup][:tools]).to eq([{ google_search: {} }])
      end
    end

    context "with context window compression" do
      let(:config) do
        Gemini::Live::Configuration.new(
          context_window_compression: {
            slidingWindow: { targetTokens: 10000 },
            triggerTokens: 16000
          }
        )
      end

      it "includes compression config" do
        message = described_class.setup(config)

        expect(message[:setup][:contextWindowCompression]).to eq({
          slidingWindow: { targetTokens: 10000 },
          triggerTokens: 16000
        })
      end
    end

    context "with session resumption" do
      let(:config) do
        Gemini::Live::Configuration.new(
          session_resumption: { handle: "token123" }
        )
      end

      it "includes session resumption" do
        message = described_class.setup(config)

        expect(message[:setup][:sessionResumption]).to eq({ handle: "token123" })
      end
    end

    context "with manual VAD" do
      let(:config) do
        Gemini::Live::Configuration.new(
          automatic_activity_detection: false
        )
      end

      it "disables automatic activity detection" do
        message = described_class.setup(config)

        expect(message[:setup][:realtimeInputConfig]).to eq({
          automaticActivityDetection: {
            disabled: true
          }
        })
      end
    end

    context "with model that already has models/ prefix" do
      let(:config) do
        Gemini::Live::Configuration.new(model: "models/gemini-2.5-flash-native-audio-preview-12-2025")
      end

      it "does not duplicate the prefix" do
        message = described_class.setup(config)

        expect(message[:setup][:model]).to eq("models/gemini-2.5-flash-native-audio-preview-12-2025")
      end
    end
  end

  describe ".client_content" do
    it "builds correct text message" do
      message = described_class.client_content(text: "Hello!")

      expect(message[:clientContent][:turns][0][:role]).to eq("user")
      expect(message[:clientContent][:turns][0][:parts][0][:text]).to eq("Hello!")
      expect(message[:clientContent][:turnComplete]).to be true
    end

    it "respects turn_complete option" do
      message = described_class.client_content(text: "Hello!", turn_complete: false)

      expect(message[:clientContent][:turnComplete]).to be false
    end

    it "allows custom role" do
      message = described_class.client_content(text: "Hello!", role: "model")

      expect(message[:clientContent][:turns][0][:role]).to eq("model")
    end
  end

  describe ".realtime_input" do
    it "builds audio message" do
      message = described_class.realtime_input(
        audio_data: "base64audiodata",
        mime_type: "audio/pcm;rate=16000"
      )

      expect(message[:realtimeInput][:mediaChunks][0][:mimeType]).to eq("audio/pcm;rate=16000")
      expect(message[:realtimeInput][:mediaChunks][0][:data]).to eq("base64audiodata")
    end

    it "builds video message" do
      message = described_class.realtime_input(
        video_data: "base64imagedata",
        mime_type: "image/jpeg"
      )

      expect(message[:realtimeInput][:mediaChunks][0][:mimeType]).to eq("image/jpeg")
      expect(message[:realtimeInput][:mediaChunks][0][:data]).to eq("base64imagedata")
    end
  end

  describe ".activity_start" do
    it "builds activity start message" do
      message = described_class.activity_start

      expect(message[:realtimeInput][:activityStart]).to eq({})
    end
  end

  describe ".activity_end" do
    it "builds activity end message" do
      message = described_class.activity_end

      expect(message[:realtimeInput][:activityEnd]).to eq({})
    end
  end

  describe ".tool_response" do
    it "builds tool response message" do
      function_responses = [
        { id: "call_1", name: "get_weather", response: { result: "Sunny" } },
        { id: "call_2", name: "get_time", response: { result: "12:00" } }
      ]

      message = described_class.tool_response(function_responses)

      expect(message[:toolResponse][:functionResponses]).to eq([
        { id: "call_1", name: "get_weather", response: { result: "Sunny" } },
        { id: "call_2", name: "get_time", response: { result: "12:00" } }
      ])
    end

    context "with scheduling for async (NON_BLOCKING) function calls" do
      it "preserves scheduling already inside the response payload and uppercases it" do
        message = described_class.tool_response([
          { id: "x", name: "fn", response: { result: "ok", scheduling: :interrupt } }
        ])

        expect(message[:toolResponse][:functionResponses].first[:response]).to eq({
          result: "ok",
          scheduling: "INTERRUPT"
        })
      end

      it "accepts scheduling as a top-level shortcut and merges it into the response" do
        message = described_class.tool_response([
          { id: "x", name: "fn", response: { result: "ok" }, scheduling: "WHEN_IDLE" }
        ])

        expect(message[:toolResponse][:functionResponses].first[:response]).to eq({
          result: "ok",
          scheduling: "WHEN_IDLE"
        })
      end

      it "wraps non-Hash response values into { result: ... } when scheduling is given" do
        message = described_class.tool_response([
          { id: "x", name: "fn", response: "ok", scheduling: "SILENT" }
        ])

        expect(message[:toolResponse][:functionResponses].first[:response]).to eq({
          result: "ok",
          scheduling: "SILENT"
        })
      end

      it "raises ArgumentError for invalid scheduling values" do
        expect {
          described_class.tool_response([
            { id: "x", name: "fn", response: { result: "ok" }, scheduling: "BOGUS" }
          ])
        }.to raise_error(ArgumentError, /scheduling must be one of/)
      end

      it "accepts a String scheduling key inside the response payload" do
        message = described_class.tool_response([
          { id: "x", name: "fn", response: { "result" => "ok", "scheduling" => "interrupt" } }
        ])

        payload = message[:toolResponse][:functionResponses].first[:response]
        expect(payload[:scheduling]).to eq("INTERRUPT")
        expect(payload).not_to have_key("scheduling")
      end
    end
  end
end
