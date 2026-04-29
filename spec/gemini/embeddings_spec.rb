require 'spec_helper'

RSpec.describe Gemini::Embeddings do
  let(:api_key) { 'test_api_key' }
  let(:client) { Gemini::Client.new(api_key) }
  let(:base_url) { "https://generativelanguage.googleapis.com/v1beta" }
  let(:default_model) { "gemini-embedding-001" }

  let(:single_response_body) do
    {
      "embedding" => {
        "values" => [0.1, 0.2, 0.3, 0.4]
      }
    }
  end

  let(:batch_response_body) do
    {
      "embeddings" => [
        { "values" => [0.1, 0.2, 0.3] },
        { "values" => [0.4, 0.5, 0.6] }
      ]
    }
  end

  describe "#create" do
    context "with a String input" do
      before do
        stub_request(:post, "#{base_url}/models/#{default_model}:embedContent?key=#{api_key}")
          .with(
            body: hash_including(
              content: { parts: [{ text: "Hello world" }] }
            ),
            headers: { "Content-Type" => "application/json" }
          )
          .to_return(
            status: 200,
            body: single_response_body.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "sends an embedContent request and returns a Response object" do
        response = client.embeddings_api.create(input: "Hello world")
        expect(response).to be_a(Gemini::Response)
        expect(response.success?).to be true
      end

      it "exposes the embedding values via Response#embedding" do
        response = client.embeddings_api.create(input: "Hello world")
        expect(response.embedding).to eq([0.1, 0.2, 0.3, 0.4])
      end

      it "reports the embedding dimension" do
        response = client.embeddings_api.create(input: "Hello world")
        expect(response.embedding_dimension).to eq(4)
      end

      it "wraps the single embedding in Response#embeddings" do
        response = client.embeddings_api.create(input: "Hello world")
        expect(response.embeddings).to eq([[0.1, 0.2, 0.3, 0.4]])
      end
    end

    context "with task_type, title, and output_dimensionality" do
      it "passes the optional fields through to the API" do
        stub = stub_request(:post, "#{base_url}/models/#{default_model}:embedContent?key=#{api_key}")
          .with(
            body: hash_including(
              content: { parts: [{ text: "Doc body" }] },
              taskType: "RETRIEVAL_DOCUMENT",
              title: "My Document",
              outputDimensionality: 768
            )
          )
          .to_return(status: 200, body: single_response_body.to_json, headers: { "Content-Type" => "application/json" })

        client.embeddings_api.create(
          input: "Doc body",
          task_type: :retrieval_document,
          title: "My Document",
          output_dimensionality: 768
        )

        expect(stub).to have_been_requested
      end
    end

    context "with an Array input" do
      it "delegates to batchEmbedContents and returns multiple values" do
        stub_request(:post, "#{base_url}/models/#{default_model}:batchEmbedContents?key=#{api_key}")
          .with(
            body: hash_including(
              requests: [
                { content: { parts: [{ text: "First" }] }, model: "models/#{default_model}" },
                { content: { parts: [{ text: "Second" }] }, model: "models/#{default_model}" }
              ]
            )
          )
          .to_return(status: 200, body: batch_response_body.to_json, headers: { "Content-Type" => "application/json" })

        response = client.embeddings_api.create(input: ["First", "Second"])
        expect(response).to be_a(Gemini::Response)
        expect(response.embeddings).to eq([[0.1, 0.2, 0.3], [0.4, 0.5, 0.6]])
        expect(response.embedding).to eq([0.1, 0.2, 0.3])
      end
    end

    context "with an unrecognized task_type" do
      it "raises ArgumentError" do
        expect {
          client.embeddings_api.create(input: "Hello", task_type: :something_invalid)
        }.to raise_error(ArgumentError, /task_type must be one of/)
      end
    end

    context "with a model that has the models/ prefix" do
      it "normalizes the path" do
        stub = stub_request(:post, "#{base_url}/models/#{default_model}:embedContent?key=#{api_key}")
          .to_return(status: 200, body: single_response_body.to_json, headers: { "Content-Type" => "application/json" })

        client.embeddings_api.create(input: "Hello", model: "models/#{default_model}")
        expect(stub).to have_been_requested
      end
    end
  end

  describe "#batch_create" do
    it "sends a batchEmbedContents request with each input" do
      stub = stub_request(:post, "#{base_url}/models/#{default_model}:batchEmbedContents?key=#{api_key}")
        .with(
          body: hash_including(
            requests: [
              { content: { parts: [{ text: "A" }] }, model: "models/#{default_model}" },
              { content: { parts: [{ text: "B" }] }, model: "models/#{default_model}" },
              { content: { parts: [{ text: "C" }] }, model: "models/#{default_model}" }
            ]
          )
        )
        .to_return(status: 200, body: batch_response_body.to_json, headers: { "Content-Type" => "application/json" })

      response = client.embeddings_api.batch_create(inputs: ["A", "B", "C"])
      expect(response).to be_a(Gemini::Response)
      expect(stub).to have_been_requested
    end

    it "applies task_type, title, and output_dimensionality to every request" do
      stub = stub_request(:post, "#{base_url}/models/#{default_model}:batchEmbedContents?key=#{api_key}")
        .with(
          body: hash_including(
            requests: [
              {
                content: { parts: [{ text: "First" }] },
                taskType: "SEMANTIC_SIMILARITY",
                outputDimensionality: 256,
                model: "models/#{default_model}"
              },
              {
                content: { parts: [{ text: "Second" }] },
                taskType: "SEMANTIC_SIMILARITY",
                outputDimensionality: 256,
                model: "models/#{default_model}"
              }
            ]
          )
        )
        .to_return(status: 200, body: batch_response_body.to_json, headers: { "Content-Type" => "application/json" })

      client.embeddings_api.batch_create(
        inputs: ["First", "Second"],
        task_type: "SEMANTIC_SIMILARITY",
        output_dimensionality: 256
      )

      expect(stub).to have_been_requested
    end
  end

  describe "Gemini::Response embedding helpers" do
    it "returns the values for a single embedContent payload" do
      response = Gemini::Response.new(single_response_body)
      expect(response.valid?).to be true
      expect(response.embedding_response?).to be true
      expect(response.embedding).to eq([0.1, 0.2, 0.3, 0.4])
      expect(response.embeddings).to eq([[0.1, 0.2, 0.3, 0.4]])
      expect(response.embedding_dimension).to eq(4)
    end

    it "returns the values for a batch payload" do
      response = Gemini::Response.new(batch_response_body)
      expect(response.valid?).to be true
      expect(response.embedding_response?).to be true
      expect(response.embedding).to eq([0.1, 0.2, 0.3])
      expect(response.embeddings).to eq([[0.1, 0.2, 0.3], [0.4, 0.5, 0.6]])
    end

    it "returns nil/empty for non-embedding payloads" do
      response = Gemini::Response.new({ "candidates" => [] })
      expect(response.embedding_response?).to be false
      expect(response.embedding).to be_nil
      expect(response.embeddings).to eq([])
      expect(response.embedding_dimension).to eq(0)
    end
  end
end
