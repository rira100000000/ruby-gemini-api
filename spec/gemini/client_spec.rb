require 'spec_helper'

RSpec.describe Gemini::Client do
  let(:api_key) { ENV['GEMINI_API_KEY'] || 'test_api_key' }
  let(:client) { Gemini::Client.new(api_key) }
  let(:base_url) { "https://generativelanguage.googleapis.com/v1beta" }
  let(:response_instance) { instance_double(Gemini::Response) }

  describe "#initialize" do
    it "initializes with an API key" do
      expect(client.api_key).to eq(api_key)
    end

    it "raises an error without API key" do
      allow(ENV).to receive(:[]).with("GEMINI_API_KEY").and_return(nil)
      expect { Gemini::Client.new }.to raise_error(Gemini::ConfigurationError)
    end

    it "uses the API key from the environment if not provided" do
      allow(ENV).to receive(:[]).with("GEMINI_API_KEY").and_return("env_api_key")
      client = Gemini::Client.new
      expect(client.api_key).to eq("env_api_key")
    end
  end

  # test for image function
  describe "#generate_content with image" do
    let(:sample_text_response) { "This is a guinea pig in the image." }
    let(:response_body) do
      {
        "candidates" => [
          {
            "content" => {
              "parts" => [
                { "text" => sample_text_response }
              ],
              "role" => "model"
            },
            "finishReason" => "STOP",
            "index" => 0
          }
        ]
      }
    end

    before do
      allow(Gemini::Response).to receive(:new).and_return(response_instance)
      allow(response_instance).to receive(:text).and_return(sample_text_response)
      allow(response_instance).to receive(:raw_data).and_return(response_body)
    end

    context "with image_url" do
      let(:image_url) { "https://example.com/guinea_pig.jpg" }
      let(:prompt) { [
        { type: "text", text: "What is in this image?" },
        { type: "image_url", image_url: { url: image_url } }
      ] }
      
      before do
        # mock Base64 encoded data
        allow(client).to receive(:encode_image_from_url).with(image_url).and_return("base64_encoded_image_data")
        allow(client).to receive(:determine_mime_type).with(image_url).and_return("image/jpeg")

        stub_request(:post, "#{base_url}/models/gemini-2.5-flash:generateContent?key=#{api_key}")
          .with(
            body: hash_including(
              contents: [
                { 
                  parts: [
                    { text: "What is in this image?" },
                    { 
                      inline_data: {
                        mime_type: "image/jpeg",
                        data: "base64_encoded_image_data"
                      }
                    }
                  ]
                }
              ]
            ),
            headers: { "Content-Type" => "application/json" }
          )
          .to_return(status: 200, body: response_body.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "sends a request with image url data and returns Response object" do
        response = client.generate_content(prompt, model: "gemini-2.5-flash")
        expect(response).to be(response_instance)
        expect(response.text).to eq(sample_text_response)
      end
    end

    context "with image_file" do
      let(:file_path) { "/path/to/guinea_pig.jpg" }
      let(:prompt) { [
        { type: "text", text: "Describe this image" },
        { type: "image_file", image_file: { file_path: file_path } }
      ] }
      
      before do
        # mock Base64 encoded data
        allow(client).to receive(:encode_image_from_file).with(file_path).and_return("base64_encoded_image_data")
        allow(client).to receive(:determine_mime_type).with(file_path).and_return("image/jpeg")

        stub_request(:post, "#{base_url}/models/gemini-2.5-flash:generateContent?key=#{api_key}")
          .with(
            body: hash_including(
              contents: [
                { 
                  parts: [
                    { text: "Describe this image" },
                    { 
                      inline_data: {
                        mime_type: "image/jpeg",
                        data: "base64_encoded_image_data"
                      }
                    }
                  ]
                }
              ]
            ),
            headers: { "Content-Type" => "application/json" }
          )
          .to_return(status: 200, body: response_body.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "sends a request with image file data and returns Response object" do
        response = client.generate_content(prompt, model: "gemini-2.5-flash")
        expect(response).to be(response_instance)
        expect(response.text).to eq(sample_text_response)
      end
    end

    context "with image_base64" do
      let(:base64_data) { "base64_encoded_image_data" }
      let(:prompt) { [
        { type: "text", text: "What can you see in this image?" },
        { type: "image_base64", image_base64: { mime_type: "image/jpeg", data: base64_data } }
      ] }
      
      before do
        stub_request(:post, "#{base_url}/models/gemini-2.5-flash:generateContent?key=#{api_key}")
          .with(
            body: hash_including(
              contents: [
                { 
                  parts: [
                    { text: "What can you see in this image?" },
                    { 
                      inline_data: {
                        mime_type: "image/jpeg",
                        data: base64_data
                      }
                    }
                  ]
                }
              ]
            ),
            headers: { "Content-Type" => "application/json" }
          )
          .to_return(status: 200, body: response_body.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "sends a request with direct base64 image data and returns Response object" do
        response = client.generate_content(prompt, model: "gemini-2.5-flash")
        expect(response).to be(response_instance)
        expect(response.text).to eq(sample_text_response)
      end
    end

    context "with multiple images" do
      let(:image_url1) { "https://example.com/guinea_pig1.jpg" }
      let(:image_url2) { "https://example.com/guinea_pig2.jpg" }
      let(:prompt) { [
        { type: "text", text: "Compare these two images" },
        { type: "image_url", image_url: { url: image_url1 } },
        { type: "image_url", image_url: { url: image_url2 } }
      ] }
      
      before do
        # mock Base64 encoded data
        allow(client).to receive(:encode_image_from_url).with(image_url1).and_return("base64_encoded_image_data1")
        allow(client).to receive(:encode_image_from_url).with(image_url2).and_return("base64_encoded_image_data2")
        allow(client).to receive(:determine_mime_type).with(image_url1).and_return("image/jpeg")
        allow(client).to receive(:determine_mime_type).with(image_url2).and_return("image/jpeg")

        stub_request(:post, "#{base_url}/models/gemini-2.5-flash:generateContent?key=#{api_key}")
          .with(
            body: hash_including(
              contents: [
                { 
                  parts: [
                    { text: "Compare these two images" },
                    { 
                      inline_data: {
                        mime_type: "image/jpeg",
                        data: "base64_encoded_image_data1"
                      }
                    },
                    { 
                      inline_data: {
                        mime_type: "image/jpeg",
                        data: "base64_encoded_image_data2"
                      }
                    }
                  ]
                }
              ]
            ),
            headers: { "Content-Type" => "application/json" }
          )
          .to_return(status: 200, body: response_body.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "sends a request with multiple image data and returns Response object" do
        response = client.generate_content(prompt, model: "gemini-2.5-flash")
        expect(response).to be(response_instance)
        expect(response.text).to eq(sample_text_response)
      end
    end
  end
  
  describe "#chat" do
    let(:model) { "gemini-2.5-flash" }
    let(:response_body) do
      {
        "candidates" => [
          {
            "content" => {
              "parts" => [
                { "text" => "Hello, how can I help you today?" }
              ],
              "role" => "model"
            },
            "finishReason" => "STOP",
            "index" => 0
          }
        ]
      }
    end

    before do
      allow(Gemini::Response).to receive(:new).and_return(response_instance)
      allow(response_instance).to receive(:text).and_return("Hello, how can I help you today?")
      allow(response_instance).to receive(:raw_data).and_return(response_body)
    end

    context "with non-streaming response" do
      it "sends a generateContent request and returns Response object" do
        stub_request(:post, "#{base_url}/models/#{model}:generateContent?key=#{api_key}")
          .to_return(status: 200, body: response_body.to_json, headers: { "Content-Type" => "application/json" })
          
        response = client.chat(parameters: { contents: [{ parts: [{ text: "Hi" }] }] })
        expect(response).to be(response_instance)
        expect(response.text).to eq("Hello, how can I help you today?")
      end
    end

    context "with streaming response" do
      it "sends a streamGenerateContent request and returns Response object" do
        stub_request(:post, "#{base_url}/models/#{model}:streamGenerateContent?alt=sse&key=#{api_key}")
          .to_return(status: 200, body: response_body.to_json, headers: { "Content-Type" => "application/json" })
          
        callback = proc { |chunk| }
        response = client.chat(parameters: { contents: [{ parts: [{ text: "Hi" }] }] }, &callback)
        expect(response).to be(response_instance)
      end
    end
  end

  describe "#embeddings" do
    let(:model) { "text-embedding-model" }
    let(:response_body) do
      {
        "embedding" => {
          "values" => [0.1, 0.2, 0.3]
        }
      }
    end

    before do
      allow(Gemini::Response).to receive(:new).and_return(response_instance)
      allow(response_instance).to receive(:raw_data).and_return(response_body)
    end

    it "sends an embedContent request and returns Response object" do
      stub_request(:post, "#{base_url}/models/#{model}:embedContent?key=#{api_key}")
        .to_return(status: 200, body: response_body.to_json, headers: { "Content-Type" => "application/json" })
        
      response = client.embeddings(parameters: { content: { parts: [{ text: "Embed this text" }] } })
      expect(response).to be(response_instance)
    end
  end

  describe "#completions" do
    it "delegates to chat method and returns Response object" do
      params = { contents: [{ parts: [{ text: "Complete this" }] }] }
      expect(client).to receive(:chat).with(parameters: params).and_return(response_instance)
      
      response = client.completions(parameters: params)
      expect(response).to be(response_instance)
    end
  end

  describe "#generate_content_stream" do
    let(:model) { "gemini-2.5-flash" }
    
    before do
      allow(Gemini::Response).to receive(:new).and_return(response_instance)
    end

    it "requires a block" do
      expect { client.generate_content_stream("Hello") }.to raise_error(ArgumentError, "Block is required for streaming")
    end

    it "sends a streaming request and returns Response object" do
      prompt = "Tell me a story"
      
      expect(client).to receive(:chat) do |parameters:, &block|
        expect(parameters[:contents][0][:parts][0][:text]).to eq(prompt)
        expect(parameters[:model]).to eq(model)
        expect(block).to be_a(Proc)
        response_instance
      end
      
      callback = proc { |chunk| }
      response = client.generate_content_stream(prompt, &callback)
      expect(response).to be(response_instance)
    end
  end

  # helper method test
  describe "#determine_mime_type" do
    it "correctly identifies JPEG images" do
      expect(client.send(:determine_mime_type, "image.jpg")).to eq("image/jpeg")
      expect(client.send(:determine_mime_type, "photo.jpeg")).to eq("image/jpeg")
    end

    it "correctly identifies PNG images" do
      expect(client.send(:determine_mime_type, "icon.png")).to eq("image/png")
    end

    it "correctly identifies other supported formats" do
      expect(client.send(:determine_mime_type, "animation.gif")).to eq("image/gif")
      expect(client.send(:determine_mime_type, "photo.webp")).to eq("image/webp")
      expect(client.send(:determine_mime_type, "photo.heic")).to eq("image/heic")
      expect(client.send(:determine_mime_type, "photo.heif")).to eq("image/heif")
    end

    it "unknown formats" do
      expect(client.send(:determine_mime_type, "unknown.xyz")).to eq("application/octet-stream")
    end
  end

  describe "#encode_image_from_file" do
    let(:file_path) { "spec/fixtures/guinea_pig.jpg" }
    let(:binary_data) { "mock_binary_data" }
    let(:encoded_data) { "bW9ja19iaW5hcnlfZGF0YQ==" } # Base64 encoded "mock_binary_data"

    before do
      allow(File).to receive(:binread).with(file_path).and_return(binary_data)
    end

    it "reads file in binary mode and encodes to base64" do
      expect(client.send(:encode_image_from_file, file_path)).to eq(encoded_data)
      expect(File).to have_received(:binread).with(file_path)
    end

    it "raises error for non-existent files" do
      allow(File).to receive(:binread).with("non_existent.jpg").and_raise(Errno::ENOENT.new("No such file"))
      expect { client.send(:encode_image_from_file, "non_existent.jpg") }
        .to raise_error(Gemini::Error, /Failed to load image from file/)
    end
  end

  describe "#encode_image_from_url" do
    let(:image_url) { "https://example.com/guinea_pig.jpg" }
    let(:binary_data) { "mock_binary_data" }
    let(:encoded_data) { "bW9ja19iaW5hcnlfZGF0YQ==" } # Base64 encoded "mock_binary_data"
    let(:mock_io) { StringIO.new(binary_data) }

    before do
      require 'open-uri'
      allow(URI).to receive(:open).with(image_url, 'rb').and_return(mock_io)
    end

    it "opens URL in binary mode and encodes to base64" do
      expect(client.send(:encode_image_from_url, image_url)).to eq(encoded_data)
      expect(URI).to have_received(:open).with(image_url, 'rb')
    end

    it "raises error for invalid URLs" do
      allow(URI).to receive(:open).with("invalid_url", 'rb').and_raise(OpenURI::HTTPError.new("404 Not Found", StringIO.new))
      expect { client.send(:encode_image_from_url, "invalid_url") }
        .to raise_error(Gemini::Error, /Failed to load image from URL/)
    end
  end

  describe "#generate_content with text only" do
    let(:prompt) { "Tell me a story about Ruby" }
    let(:response_body) do
      {
        "candidates" => [
          {
            "content" => {
              "parts" => [
                { "text" => "Ruby is a dynamic, interpreted language..." }
              ],
              "role" => "model"
            },
            "finishReason" => "STOP",
            "index" => 0
          }
        ]
      }
    end

    before do
      stub_request(:post, "#{base_url}/models/gemini-2.5-flash:generateContent?key=#{api_key}")
        .with(
          body: {
            contents: [{ parts: [{ text: prompt }] }],
            generation_config: {temperature: 0.5}
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
        .to_return(status: 200, body: response_body.to_json, headers: { "Content-Type" => "application/json" })

      allow(Gemini::Response).to receive(:new).and_return(response_instance)
      allow(response_instance).to receive(:text).and_return("Ruby is a dynamic, interpreted language...")
    end

    it "sends a text-only request and returns Response object" do
      response = client.generate_content(prompt)
      expect(response).to be(response_instance)
      pp response.text
      expect(response.text).to include("Ruby is a dynamic")
    end
  end

  # ========================================
  # Thinking Model Tests (Gemini 2.5 / 3.0)
  # ========================================

  describe "#generate_content with thinking_config" do
    let(:prompt) { "Solve 2+2" }
    let(:thought_response_body) do
      {
        "candidates" => [
          {
            "content" => {
              "parts" => [
                { "text" => "Let me calculate...", "thought" => true },
                { "text" => "4" }
              ],
              "role" => "model"
            },
            "finishReason" => "STOP",
            "index" => 0
          }
        ]
      }
    end

    before do
      allow(Gemini::Response).to receive(:new).and_return(response_instance)
      allow(response_instance).to receive(:text).and_return("4")
    end

    context "with thinking_level (Gemini 3 style)" do
      it "sends thinkingConfig inside generationConfig" do
        stub_request(:post, "#{base_url}/models/gemini-3-flash-preview:generateContent?key=#{api_key}")
          .with(
            body: {
              contents: [{ parts: [{ text: prompt }] }],
              generation_config: {
                temperature: 0.5,
                "thinkingConfig" => {
                  "thinkingLevel" => "high",
                  "includeThoughts" => true
                }
              }
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
          .to_return(status: 200, body: thought_response_body.to_json, headers: { "Content-Type" => "application/json" })

        response = client.generate_content(
          prompt,
          model: "gemini-3-flash-preview",
          thinking_config: { thinking_level: "high", include_thoughts: true }
        )
        expect(response).to be(response_instance)
      end
    end

    context "with thinking_budget (Gemini 2.5 style)" do
      it "sends thinkingConfig with thinkingBudget inside generationConfig" do
        stub_request(:post, "#{base_url}/models/gemini-2.5-flash:generateContent?key=#{api_key}")
          .with(
            body: {
              contents: [{ parts: [{ text: prompt }] }],
              generation_config: {
                temperature: 0.5,
                "thinkingConfig" => {
                  "thinkingBudget" => 2048
                }
              }
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
          .to_return(status: 200, body: thought_response_body.to_json, headers: { "Content-Type" => "application/json" })

        response = client.generate_content(
          prompt,
          model: "gemini-2.5-flash",
          thinking_config: { thinking_budget: 2048 }
        )
        expect(response).to be(response_instance)
      end
    end

    context "with shorthand (true)" do
      it "converts true to thinking_level: high" do
        stub_request(:post, "#{base_url}/models/gemini-3-flash-preview:generateContent?key=#{api_key}")
          .with(
            body: {
              contents: [{ parts: [{ text: prompt }] }],
              generation_config: {
                temperature: 0.5,
                "thinkingConfig" => {
                  "thinkingLevel" => "high",
                  "includeThoughts" => true
                }
              }
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
          .to_return(status: 200, body: thought_response_body.to_json, headers: { "Content-Type" => "application/json" })

        response = client.generate_content(
          prompt,
          model: "gemini-3-flash-preview",
          thinking_config: true
        )
        expect(response).to be(response_instance)
      end
    end

    context "with shorthand (string)" do
      it "converts string to thinking_level" do
        stub_request(:post, "#{base_url}/models/gemini-3-flash-preview:generateContent?key=#{api_key}")
          .with(
            body: {
              contents: [{ parts: [{ text: prompt }] }],
              generation_config: {
                temperature: 0.5,
                "thinkingConfig" => {
                  "thinkingLevel" => "medium",
                  "includeThoughts" => true
                }
              }
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
          .to_return(status: 200, body: thought_response_body.to_json, headers: { "Content-Type" => "application/json" })

        response = client.generate_content(
          prompt,
          model: "gemini-3-flash-preview",
          thinking_config: "medium"
        )
        expect(response).to be(response_instance)
      end
    end

    context "with shorthand (integer)" do
      it "converts integer to thinking_budget" do
        stub_request(:post, "#{base_url}/models/gemini-2.5-flash:generateContent?key=#{api_key}")
          .with(
            body: {
              contents: [{ parts: [{ text: prompt }] }],
              generation_config: {
                temperature: 0.5,
                "thinkingConfig" => {
                  "thinkingBudget" => 8192
                }
              }
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
          .to_return(status: 200, body: thought_response_body.to_json, headers: { "Content-Type" => "application/json" })

        response = client.generate_content(
          prompt,
          model: "gemini-2.5-flash",
          thinking_config: 8192
        )
        expect(response).to be(response_instance)
      end
    end

    context "without thinking_config (backward compatibility)" do
      it "sends request without thinkingConfig" do
        stub_request(:post, "#{base_url}/models/gemini-2.5-flash:generateContent?key=#{api_key}")
          .with(
            body: {
              contents: [{ parts: [{ text: prompt }] }],
              generation_config: { temperature: 0.5 }
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
          .to_return(status: 200, body: thought_response_body.to_json, headers: { "Content-Type" => "application/json" })

        response = client.generate_content(prompt, model: "gemini-2.5-flash")
        expect(response).to be(response_instance)
      end
    end
  end

  describe "#normalize_thinking_config (private method)" do
    context "with hash input" do
      it "converts snake_case keys to camelCase" do
        result = client.send(:normalize_thinking_config, {
          thinking_level: "high",
          include_thoughts: true
        })
        expect(result).to eq({
          "thinkingLevel" => "high",
          "includeThoughts" => true
        })
      end

      it "handles thinking_budget" do
        result = client.send(:normalize_thinking_config, { thinking_budget: 2048 })
        expect(result).to eq({ "thinkingBudget" => 2048 })
      end

      it "handles string keys" do
        result = client.send(:normalize_thinking_config, {
          "thinking_level" => "medium",
          "include_thoughts" => false
        })
        expect(result).to eq({
          "thinkingLevel" => "medium",
          "includeThoughts" => false
        })
      end

      it "returns hash as-is if already in API format" do
        input = { "thinkingLevel" => "high", "includeThoughts" => true }
        result = client.send(:normalize_thinking_config, input)
        expect(result).to eq(input)
      end
    end

    context "with string input" do
      it "converts to thinkingLevel with includeThoughts" do
        result = client.send(:normalize_thinking_config, "high")
        expect(result).to eq({
          "thinkingLevel" => "high",
          "includeThoughts" => true
        })
      end
    end

    context "with integer input" do
      it "converts to thinkingBudget" do
        result = client.send(:normalize_thinking_config, 4096)
        expect(result).to eq({ "thinkingBudget" => 4096 })
      end
    end

    context "with boolean input" do
      it "converts true to default high level" do
        result = client.send(:normalize_thinking_config, true)
        expect(result).to eq({
          "thinkingLevel" => "high",
          "includeThoughts" => true
        })
      end

      it "converts false to nil" do
        result = client.send(:normalize_thinking_config, false)
        expect(result).to be_nil
      end
    end

    context "with nil input" do
      it "returns nil" do
        result = client.send(:normalize_thinking_config, nil)
        expect(result).to be_nil
      end
    end
  end
end