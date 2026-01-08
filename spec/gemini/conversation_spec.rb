require 'spec_helper'

RSpec.describe Gemini::Conversation do
  let(:api_key) { ENV['GEMINI_API_KEY'] || 'test_api_key' }
  let(:client) { Gemini::Client.new(api_key) }
  let(:model) { "gemini-2.5-flash" }
  let(:response_instance) { instance_double(Gemini::Response) }

  describe "#initialize" do
    it "initializes with required parameters" do
      conversation = Gemini::Conversation.new(client: client, model: model)
      expect(conversation.client).to eq(client)
      expect(conversation.model).to eq(model)
      expect(conversation.history).to eq([])
    end

    it "accepts optional system_instruction" do
      system_instruction = "You are a helpful assistant."
      conversation = Gemini::Conversation.new(
        client: client,
        model: model,
        system_instruction: system_instruction
      )
      expect(conversation.system_instruction).to eq(system_instruction)
    end

    it "accepts optional thinking_config" do
      thinking_config = { thinking_level: "high", include_thoughts: true }
      conversation = Gemini::Conversation.new(
        client: client,
        model: model,
        thinking_config: thinking_config
      )
      expect(conversation.thinking_config).to eq(thinking_config)
    end

    it "initializes with empty history" do
      conversation = Gemini::Conversation.new(client: client, model: model)
      expect(conversation.history).to be_empty
    end
  end

  describe "#send_message" do
    let(:conversation) { Gemini::Conversation.new(client: client, model: model) }
    let(:user_message) { "Hello, how are you?" }
    let(:model_response_text) { "I'm doing well, thank you!" }
    let(:response_data) do
      {
        "candidates" => [
          {
            "content" => {
              "parts" => [{ "text" => model_response_text }],
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
      allow(response_instance).to receive(:text).and_return(model_response_text)
      allow(response_instance).to receive(:valid?).and_return(true)
      allow(response_instance).to receive(:content_for_history).and_return({
        "role" => "model",
        "parts" => [{ "text" => model_response_text }]
      })
      allow(client).to receive(:chat).and_return(response_instance)
    end

    it "sends a message and returns a Response object" do
      response = conversation.send_message(user_message)
      expect(response).to be(response_instance)
      expect(response.text).to eq(model_response_text)
    end

    it "adds user message to history" do
      conversation.send_message(user_message)
      expect(conversation.history.size).to eq(2) # user + model
      expect(conversation.history[0]["role"]).to eq("user")
      expect(conversation.history[0]["parts"]).to eq([{ "text" => user_message }])
    end

    it "adds model response to history" do
      conversation.send_message(user_message)
      expect(conversation.history.size).to eq(2)
      expect(conversation.history[1]["role"]).to eq("model")
      expect(conversation.history[1]["parts"]).to eq([{ "text" => model_response_text }])
    end

    it "maintains conversation context across multiple messages" do
      conversation.send_message("First message")
      conversation.send_message("Second message")

      expect(conversation.history.size).to eq(4) # 2 user + 2 model
      expect(conversation.history.map { |msg| msg["role"] }).to eq(["user", "model", "user", "model"])
    end

    it "passes history to client.chat" do
      conversation.send_message("First message")

      expect(client).to receive(:chat) do |parameters:|
        contents = parameters[:contents]
        # Should include previous history + new message
        expect(contents.size).to eq(3) # first user, first model, second user
        response_instance
      end

      conversation.send_message("Second message")
    end
  end

  describe "#send_message with thinking_config" do
    let(:thinking_config) { { thinking_level: "high", include_thoughts: true } }
    let(:conversation) do
      Gemini::Conversation.new(
        client: client,
        model: model,
        thinking_config: thinking_config
      )
    end
    let(:user_message) { "Solve 2+2" }

    before do
      allow(Gemini::Response).to receive(:new).and_return(response_instance)
      allow(response_instance).to receive(:text).and_return("4")
      allow(response_instance).to receive(:valid?).and_return(true)
      allow(response_instance).to receive(:content_for_history).and_return({
        "role" => "model",
        "parts" => [{ "text" => "4" }]
      })
    end

    it "passes thinking_config to client.chat" do
      expect(client).to receive(:chat) do |parameters:|
        expect(parameters[:generation_config]).to have_key("thinkingConfig")
        expect(parameters[:generation_config]["thinkingConfig"]["thinkingLevel"]).to eq("high")
        expect(parameters[:generation_config]["thinkingConfig"]["includeThoughts"]).to be true
        response_instance
      end

      conversation.send_message(user_message)
    end
  end

  describe "#send_message with thought signatures" do
    let(:thinking_config) { true }
    let(:conversation) do
      Gemini::Conversation.new(
        client: client,
        model: "gemini-3-flash-preview",
        thinking_config: thinking_config
      )
    end
    let(:user_message) { "What is 10 * 5?" }
    let(:thought_response_data) do
      {
        "candidates" => [
          {
            "content" => {
              "parts" => [
                { "text" => "Let me calculate...", "thought" => true },
                { "text" => "50", "thoughtSignature" => "encrypted_sig_123" }
              ],
              "role" => "model"
            }
          }
        ]
      }
    end

    before do
      allow(Gemini::Response).to receive(:new).and_return(response_instance)
      allow(response_instance).to receive(:text).and_return("50")
      allow(response_instance).to receive(:valid?).and_return(true)
      allow(response_instance).to receive(:content_for_history).and_return({
        "role" => "model",
        "parts" => [
          { "text" => "Let me calculate..." },
          { "text" => "50" }
        ]
      })
      allow(client).to receive(:chat).and_return(response_instance)
    end

    it "preserves thought signatures in conversation history" do
      # First message
      allow(response_instance).to receive(:content_for_history).and_return({
        "role" => "model",
        "parts" => [
          { "text" => "Let me calculate..." },
          { "text" => "50", "thoughtSignature" => "encrypted_sig_123" }
        ]
      })

      conversation.send_message(user_message)

      expect(conversation.history.size).to eq(2)
      model_response = conversation.history[1]

      # Check if signature is preserved in a part
      has_signature = model_response["parts"].any? { |p| p.key?("thoughtSignature") }
      expect(has_signature).to be true
    end

    it "includes signatures in subsequent requests" do
      # First message with signature
      allow(response_instance).to receive(:content_for_history).and_return({
        "role" => "model",
        "parts" => [
          { "text" => "50", "thoughtSignature" => "encrypted_sig_123" }
        ]
      })

      conversation.send_message(user_message)

      # Second message should include the signature from first response
      expect(client).to receive(:chat) do |parameters:|
        contents = parameters[:contents]
        # Should have: user1, model1 (with signature), user2
        expect(contents.size).to eq(3)

        model_content = contents[1]
        has_signature = model_content["parts"].any? { |p| p.key?("thoughtSignature") }
        expect(has_signature).to be true

        response_instance
      end

      conversation.send_message("Square that number")
    end
  end

  describe "#clear_history" do
    let(:conversation) { Gemini::Conversation.new(client: client, model: model) }

    before do
      allow(Gemini::Response).to receive(:new).and_return(response_instance)
      allow(response_instance).to receive(:text).and_return("Response")
      allow(response_instance).to receive(:valid?).and_return(true)
      allow(response_instance).to receive(:content_for_history).and_return({
        "role" => "model",
        "parts" => [{ "text" => "Response" }]
      })
      allow(client).to receive(:chat).and_return(response_instance)
    end

    it "clears conversation history" do
      conversation.send_message("First message")
      conversation.send_message("Second message")

      expect(conversation.history.size).to eq(4)

      conversation.clear_history

      expect(conversation.history).to be_empty
    end

    it "allows starting a new conversation after clearing" do
      conversation.send_message("Old message")
      conversation.clear_history
      conversation.send_message("New message")

      expect(conversation.history.size).to eq(2) # Only new user + model
    end
  end

  describe "#get_history" do
    let(:conversation) { Gemini::Conversation.new(client: client, model: model) }

    before do
      allow(Gemini::Response).to receive(:new).and_return(response_instance)
      allow(response_instance).to receive(:text).and_return("Response")
      allow(response_instance).to receive(:valid?).and_return(true)
      allow(response_instance).to receive(:content_for_history).and_return({
        "role" => "model",
        "parts" => [{ "text" => "Response" }]
      })
      allow(client).to receive(:chat).and_return(response_instance)
    end

    it "returns a copy of the history" do
      conversation.send_message("Test message")
      history = conversation.get_history

      expect(history).to eq(conversation.history)
      expect(history).not_to be(conversation.history) # Different object
    end

    it "prevents external modification of internal history" do
      conversation.send_message("Test message")
      history = conversation.get_history

      history.clear

      expect(conversation.history).not_to be_empty
    end
  end

  describe "#send_message with system_instruction" do
    let(:system_instruction) { "You are a math tutor." }
    let(:conversation) do
      Gemini::Conversation.new(
        client: client,
        model: model,
        system_instruction: system_instruction
      )
    end

    before do
      allow(Gemini::Response).to receive(:new).and_return(response_instance)
      allow(response_instance).to receive(:text).and_return("Response")
      allow(response_instance).to receive(:valid?).and_return(true)
      allow(response_instance).to receive(:content_for_history).and_return({
        "role" => "model",
        "parts" => [{ "text" => "Response" }]
      })
    end

    it "includes system_instruction in the request" do
      expect(client).to receive(:chat) do |parameters:|
        expect(parameters).to have_key(:system_instruction)
        response_instance
      end

      conversation.send_message("Help me with math")
    end
  end

  describe "#send_message with additional options" do
    let(:conversation) { Gemini::Conversation.new(client: client, model: model) }
    let(:tools) { [{ function_declarations: [{ name: "test_func" }] }] }

    before do
      allow(Gemini::Response).to receive(:new).and_return(response_instance)
      allow(response_instance).to receive(:text).and_return("Response")
      allow(response_instance).to receive(:valid?).and_return(true)
      allow(response_instance).to receive(:content_for_history).and_return({
        "role" => "model",
        "parts" => [{ "text" => "Response" }]
      })
    end

    it "passes additional options to client.chat" do
      expect(client).to receive(:chat) do |parameters:|
        expect(parameters[:tools]).to eq(tools)
        response_instance
      end

      conversation.send_message("Test", tools: tools)
    end
  end

  describe "integration with normalize_parts" do
    let(:conversation) { Gemini::Conversation.new(client: client, model: model) }

    before do
      allow(Gemini::Response).to receive(:new).and_return(response_instance)
      allow(response_instance).to receive(:text).and_return("Response")
      allow(response_instance).to receive(:valid?).and_return(true)
      allow(response_instance).to receive(:content_for_history).and_return({
        "role" => "model",
        "parts" => [{ "text" => "Response" }]
      })
      allow(client).to receive(:chat).and_return(response_instance)
    end

    it "normalizes string content to parts format" do
      conversation.send_message("Simple string")
      user_message = conversation.history[0]

      expect(user_message["parts"]).to eq([{ "text" => "Simple string" }])
    end

    it "normalizes array content to parts format" do
      conversation.send_message([
        { type: "text", text: "Part 1" },
        { type: "text", text: "Part 2" }
      ])

      user_message = conversation.history[0]
      expect(user_message["parts"].size).to eq(2)
    end

    it "handles hash with parts key" do
      content = {
        parts: [
          { "text" => "Custom part 1" },
          { "text" => "Custom part 2" }
        ]
      }

      conversation.send_message(content)
      user_message = conversation.history[0]

      expect(user_message["parts"]).to eq(content[:parts])
    end
  end
end
