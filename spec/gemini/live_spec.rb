# frozen_string_literal: true

RSpec.describe Gemini::Live do
  let(:api_key) { "test_api_key" }
  let(:client) { Gemini::Client.new(api_key) }
  let(:live) { described_class.new(client: client) }

  describe "#initialize" do
    it "stores the client reference" do
      expect(live.instance_variable_get(:@client)).to eq(client)
    end
  end

  describe "#connect" do
    let(:mock_ws) { instance_double(WebSocket::Client::Simple::Client) }
    let(:mock_session) { instance_double(Gemini::Live::Session) }

    before do
      allow(WebSocket::Client::Simple).to receive(:connect).and_return(mock_ws)
      allow(mock_ws).to receive(:on)
      allow(Gemini::Live::Session).to receive(:new).and_return(mock_session)
    end

    it "creates a session with default configuration" do
      expect(Gemini::Live::Session).to receive(:new).with(
        api_key: api_key,
        configuration: an_instance_of(Gemini::Live::Configuration)
      )

      live.connect
    end

    it "passes configuration options to Configuration" do
      expect(Gemini::Live::Configuration).to receive(:new).with(
        model: "custom-model",
        response_modality: "AUDIO",
        voice_name: "Puck",
        system_instruction: "Be helpful",
        tools: [{ google_search: {} }],
        context_window_compression: nil,
        session_resumption: nil,
        automatic_activity_detection: false,
        media_resolution: nil,
        output_audio_transcription: true
      ).and_call_original

      live.connect(
        model: "custom-model",
        response_modality: "AUDIO",
        voice_name: "Puck",
        system_instruction: "Be helpful",
        tools: [{ google_search: {} }],
        automatic_activity_detection: false,
        output_audio_transcription: true
      )
    end

    it "returns the session when no block given" do
      result = live.connect
      expect(result).to eq(mock_session)
    end

    context "with block" do
      before do
        allow(mock_session).to receive(:close)
      end

      it "yields the session to the block" do
        expect { |b| live.connect(&b) }.to yield_with_args(mock_session)
      end

      it "closes the session after the block" do
        allow(mock_session).to receive(:close)

        live.connect do |session|
          # do nothing
        end

        expect(mock_session).to have_received(:close)
      end

      it "closes the session even if block raises an error" do
        allow(mock_session).to receive(:close)

        expect {
          live.connect do |session|
            raise "Test error"
          end
        }.to raise_error("Test error")

        expect(mock_session).to have_received(:close)
      end
    end
  end
end

RSpec.describe Gemini::Client do
  let(:api_key) { "test_api_key" }
  let(:client) { described_class.new(api_key) }

  describe "#live" do
    it "returns a Live instance" do
      expect(client.live).to be_a(Gemini::Live)
    end

    it "caches the Live instance" do
      live1 = client.live
      live2 = client.live
      expect(live1).to be(live2)
    end
  end
end
