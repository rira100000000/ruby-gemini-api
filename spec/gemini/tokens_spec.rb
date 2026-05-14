require 'spec_helper'

RSpec.describe Gemini::Tokens do
  let(:api_key) { 'test_api_key' }
  let(:client) { Gemini::Client.new(api_key) }
  let(:base_url) { "https://generativelanguage.googleapis.com/v1beta" }
  let(:default_model) { "gemini-2.5-flash" }

  let(:simple_response_body) do
    {
      "totalTokens" => 31,
      "promptTokensDetails" => [
        { "modality" => "TEXT", "tokenCount" => 31 }
      ]
    }
  end

  describe "#count" do
    context "with a String input" do
      before do
        stub_request(:post, "#{base_url}/models/#{default_model}:countTokens?key=#{api_key}")
          .with(
            body: hash_including(
              contents: [{ parts: [{ text: "The quick brown fox jumps over the lazy dog." }] }]
            ),
            headers: { "Content-Type" => "application/json" }
          )
          .to_return(
            status: 200,
            body: simple_response_body.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "sends a countTokens request and returns a Response object" do
        response = client.tokens.count("The quick brown fox jumps over the lazy dog.")
        expect(response).to be_a(Gemini::Response)
        expect(response.success?).to be true
      end

      it "exposes the totalTokens value via Response#count_tokens" do
        response = client.tokens.count("The quick brown fox jumps over the lazy dog.")
        expect(response.count_tokens).to eq(31)
        expect(response.count_tokens_response?).to be true
      end

      it "exposes the per-modality breakdown" do
        response = client.tokens.count("The quick brown fox jumps over the lazy dog.")
        expect(response.prompt_tokens_details).to eq([
          { "modality" => "TEXT", "tokenCount" => 31 }
        ])
      end
    end

    context "with an explicit contents array" do
      it "passes the contents through without rewrapping" do
        stub_request(:post, "#{base_url}/models/#{default_model}:countTokens?key=#{api_key}")
          .with(
            body: hash_including(
              contents: [
                { role: "user", parts: [{ text: "Hi" }] },
                { role: "model", parts: [{ text: "Hello!" }] }
              ]
            )
          )
          .to_return(status: 200, body: simple_response_body.to_json,
                     headers: { "Content-Type" => "application/json" })

        response = client.tokens.count(
          contents: [
            { role: "user", parts: [{ text: "Hi" }] },
            { role: "model", parts: [{ text: "Hello!" }] }
          ]
        )
        expect(response.count_tokens).to eq(31)
      end
    end

    context "with system_instruction or tools" do
      it "wraps the payload in generateContentRequest" do
        stub_request(:post, "#{base_url}/models/#{default_model}:countTokens?key=#{api_key}")
          .with do |req|
            body = JSON.parse(req.body)
            body.key?("generateContentRequest") &&
              body["generateContentRequest"]["model"] == "models/#{default_model}" &&
              body["generateContentRequest"]["contents"] == [{ "parts" => [{ "text" => "Hello" }] }] &&
              body["generateContentRequest"]["systemInstruction"] == { "parts" => [{ "text" => "You are concise." }] }
          end
          .to_return(status: 200, body: simple_response_body.to_json,
                     headers: { "Content-Type" => "application/json" })

        response = client.tokens.count("Hello", system_instruction: "You are concise.")
        expect(response.count_tokens).to eq(31)
      end
    end

    context "when input is missing" do
      it "raises ArgumentError" do
        expect { client.tokens.count }.to raise_error(ArgumentError)
      end
    end

    context "with model prefix" do
      it "normalizes models/<id> prefixed model names" do
        stub_request(:post, "#{base_url}/models/gemini-2.5-pro:countTokens?key=#{api_key}")
          .to_return(status: 200, body: simple_response_body.to_json,
                     headers: { "Content-Type" => "application/json" })

        response = client.tokens.count("Hi", model: "models/gemini-2.5-pro")
        expect(response.success?).to be true
      end
    end
  end

  describe "Client#count_tokens" do
    it "delegates to Tokens#count" do
      stub_request(:post, "#{base_url}/models/#{default_model}:countTokens?key=#{api_key}")
        .with(body: hash_including(contents: [{ parts: [{ text: "Hello" }] }]))
        .to_return(status: 200, body: simple_response_body.to_json,
                   headers: { "Content-Type" => "application/json" })

      response = client.count_tokens("Hello")
      expect(response.count_tokens).to eq(31)
    end
  end
end
