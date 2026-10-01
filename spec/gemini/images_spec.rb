require 'spec_helper'

RSpec.describe Gemini::Images do
  let(:api_key) { 'test_api_key' }
  let(:client) { Gemini::Client.new(api_key) }
  let(:base_url) { "https://generativelanguage.googleapis.com/v1beta" }
  let(:response_body) { { "candidates" => [] }.to_json }
  let(:json_headers) { { "Content-Type" => "application/json" } }

  describe "#generate" do
    it "uses the default Gemini image model when no model is given" do
      stub = stub_request(:post, "#{base_url}/models/#{described_class::DEFAULT_MODEL}:generateContent?key=#{api_key}")
        .to_return(status: 200, body: response_body, headers: json_headers)

      client.images.generate(parameters: { prompt: "a cat" })

      expect(described_class::DEFAULT_MODEL).to eq("gemini-3.1-flash-image")
      expect(stub).to have_been_requested
    end

    it "uses the default Gemini image model for image editing" do
      stub = stub_request(:post, "#{base_url}/models/#{described_class::DEFAULT_MODEL}:generateContent?key=#{api_key}")
        .to_return(status: 200, body: response_body, headers: json_headers)

      client.images.generate(parameters: { prompt: "make it blue", image_base64: "aGVsbG8=" })

      expect(stub).to have_been_requested
    end

    it "still calls :predict for Imagen models but emits a deprecation warning" do
      stub = stub_request(:post, "#{base_url}/models/imagen-4.0-generate-001:predict?key=#{api_key}")
        .to_return(status: 200, body: { "predictions" => [] }.to_json, headers: json_headers)

      expect {
        client.images.generate(parameters: { prompt: "a cat", model: "imagen-4.0-generate-001" })
      }.to output(/DEPRECATION: Imagen models \(imagen-4\.0-generate-001\)/).to_stderr

      expect(stub).to have_been_requested
    end
  end
end
