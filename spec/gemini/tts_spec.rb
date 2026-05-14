require 'spec_helper'
require 'base64'
require 'tmpdir'

RSpec.describe Gemini::TTS do
  let(:api_key) { 'test_api_key' }
  let(:client) { Gemini::Client.new(api_key) }
  let(:base_url) { "https://generativelanguage.googleapis.com/v1beta" }
  let(:default_model) { "gemini-2.5-flash-preview-tts" }

  # 100 zero bytes of PCM = simple valid payload
  let(:pcm_bytes) { "\x00".b * 100 }
  let(:audio_b64) { Base64.strict_encode64(pcm_bytes) }
  let(:audio_response_body) do
    {
      "candidates" => [{
        "content" => {
          "parts" => [{
            "inlineData" => {
              "mimeType" => "audio/L16;codec=pcm;rate=24000",
              "data" => audio_b64
            }
          }]
        }
      }]
    }
  end

  describe "#generate" do
    context "single-speaker" do
      it "sends responseModalities=[AUDIO] and prebuiltVoiceConfig.voiceName" do
        stub_request(:post, "#{base_url}/models/#{default_model}:generateContent?key=#{api_key}")
          .with do |req|
            body = JSON.parse(req.body)
            body["contents"] == [{ "parts" => [{ "text" => "Hello world" }] }] &&
              body["generationConfig"]["responseModalities"] == ["AUDIO"] &&
              body.dig("generationConfig", "speechConfig", "voiceConfig", "prebuiltVoiceConfig", "voiceName") == "Kore"
          end
          .to_return(status: 200, body: audio_response_body.to_json,
                     headers: { "Content-Type" => "application/json" })

        response = client.tts.generate("Hello world", voice: "Kore")
        expect(response.success?).to be true
        expect(response.audio_response?).to be true
        expect(response.audio_mime_type).to eq("audio/L16;codec=pcm;rate=24000")
        expect(response.audio_data).to eq(audio_b64)
      end
    end

    context "multi-speaker" do
      it "builds multiSpeakerVoiceConfig.speakerVoiceConfigs" do
        stub_request(:post, "#{base_url}/models/#{default_model}:generateContent?key=#{api_key}")
          .with do |req|
            body = JSON.parse(req.body)
            configs = body.dig("generationConfig", "speechConfig",
                               "multiSpeakerVoiceConfig", "speakerVoiceConfigs")
            configs.is_a?(Array) &&
              configs.size == 2 &&
              configs[0]["speaker"] == "Joe" &&
              configs[0].dig("voiceConfig", "prebuiltVoiceConfig", "voiceName") == "Kore" &&
              configs[1]["speaker"] == "Jane" &&
              configs[1].dig("voiceConfig", "prebuiltVoiceConfig", "voiceName") == "Puck"
          end
          .to_return(status: 200, body: audio_response_body.to_json,
                     headers: { "Content-Type" => "application/json" })

        response = client.tts.generate(
          "Joe: Hello. Jane: Hi!",
          multi_speaker: [
            { speaker: "Joe",  voice: "Kore" },
            { speaker: "Jane", voice: "Puck" }
          ]
        )
        expect(response.success?).to be true
      end
    end

    context "with model override" do
      it "uses the given model path" do
        stub_request(:post, "#{base_url}/models/gemini-2.5-pro-preview-tts:generateContent?key=#{api_key}")
          .to_return(status: 200, body: audio_response_body.to_json,
                     headers: { "Content-Type" => "application/json" })

        response = client.tts.generate("hi", voice: "Kore", model: "gemini-2.5-pro-preview-tts")
        expect(response.success?).to be true
      end
    end

    context "validation" do
      it "raises when text is empty" do
        expect { client.tts.generate("", voice: "Kore") }.to raise_error(ArgumentError, /text is required/)
      end

      it "raises when voice is unknown" do
        expect { client.tts.generate("hi", voice: "Bogus") }
          .to raise_error(ArgumentError, /Unknown voice/)
      end

      it "raises when both voice and multi_speaker are given" do
        expect {
          client.tts.generate("hi", voice: "Kore",
                              multi_speaker: [{ speaker: "A", voice: "Puck" }])
        }.to raise_error(ArgumentError, /mutually exclusive/)
      end

      it "raises when multi_speaker entry is missing fields" do
        expect {
          client.tts.generate("hi", multi_speaker: [{ speaker: "A" }])
        }.to raise_error(ArgumentError, /:speaker and :voice/)
      end

      it "raises when neither voice nor multi_speaker is provided" do
        expect { client.tts.generate("hi") }.to raise_error(ArgumentError)
      end
    end
  end

  describe "Client#generate_speech" do
    it "delegates to TTS#generate" do
      stub_request(:post, "#{base_url}/models/#{default_model}:generateContent?key=#{api_key}")
        .to_return(status: 200, body: audio_response_body.to_json,
                   headers: { "Content-Type" => "application/json" })

      response = client.generate_speech("Hello", voice: "Kore")
      expect(response.audio_response?).to be true
    end
  end

  describe "Response#save_audio" do
    before do
      stub_request(:post, "#{base_url}/models/#{default_model}:generateContent?key=#{api_key}")
        .to_return(status: 200, body: audio_response_body.to_json,
                   headers: { "Content-Type" => "application/json" })
    end

    it "wraps L16 PCM in a WAV header and writes the file" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "out.wav")
        response = client.tts.generate("Hi", voice: "Kore")
        expect(response.save_audio(path)).to eq(path)

        data = File.binread(path)
        expect(data[0, 4]).to eq("RIFF")
        expect(data[8, 4]).to eq("WAVE")
        expect(data[12, 4]).to eq("fmt ")
        # PCM data follows a 44-byte RIFF header
        expect(data.bytesize).to eq(44 + pcm_bytes.bytesize)
        # Sample rate at offset 24 (little-endian uint32)
        expect(data[24, 4].unpack1("V")).to eq(24000)
      end
    end

    it "returns nil when there is no audio data" do
      response = Gemini::Response.new({ "candidates" => [{ "content" => { "parts" => [{ "text" => "hi" }] } }] })
      Dir.mktmpdir do |dir|
        expect(response.save_audio(File.join(dir, "x.wav"))).to be_nil
      end
    end
  end
end
