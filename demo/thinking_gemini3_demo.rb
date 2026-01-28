#!/usr/bin/env ruby
# frozen_string_literal: true

# Gemini 3 Thinking Feature Demo
#
# Gemini 3 uses thinking_level (:minimal, :low, :medium, :high)
# Thought Signature is required for Function Calling continuation
#
# Usage:
#   ruby demo/thinking_gemini3_demo.rb
#
# Environment variables:
#   GEMINI_API_KEY - Gemini API key (required)

require 'bundler/setup'
require 'gemini'

api_key = ENV['GEMINI_API_KEY'] || raise("Please set the GEMINI_API_KEY environment variable")

MODEL = "gemini-3-flash-preview"

begin
  puts "=" * 60
  puts "Gemini 3 Thinking Feature Demo"
  puts "Model: #{MODEL}"
  puts "=" * 60

  client = Gemini::Client.new(api_key)

  # ============================================================
  # Demo 1: Comparing thinking_level
  # ============================================================
  puts "\n### Demo 1: Comparing thinking_level ###\n"
  puts "Comparing the same question with different thinking_level values"
  puts "-" * 40

  prompt = "Explain three main ethical challenges of AI."

  %i[minimal low medium high].each do |level|
    puts "\n[thinking_level: #{level}]"

    response = client.generate_content(
      prompt,
      model: MODEL,
      thinking_level: level
    )

    if response.success?
      puts "Thoughts tokens: #{response.thoughts_token_count || 'N/A'}"
      puts "Answer (first 150 chars):"
      text = response.text || ""
      puts text[0..150] + (text.length > 150 ? "..." : "")
    else
      puts "Error: #{response.error}"
    end
  end

  # ============================================================
  # Demo 2: Function Calling + Thinking (Gemini 3)
  # ============================================================
  puts "\n\n### Demo 2: Function Calling + Thinking (Gemini 3) ###\n"
  puts "Gemini 3 requires Signature for Function Calling continuation"
  puts "-" * 40

  # Tool definition
  tools = Gemini::ToolDefinition.new do
    function :get_stock_price, description: "Get stock price" do
      property :symbol, type: :string, description: "Ticker symbol", required: true
      property :exchange, type: :string, description: "Stock exchange"
    end

    function :get_weather, description: "Get weather" do
      property :location, type: :string, description: "Location", required: true
    end
  end

  puts "\nInitial request..."
  response = client.generate_content(
    "What is the stock price of Toyota (7203.T)?",
    model: MODEL,
    tools: tools,
    thinking_level: :medium
  )

  if response.success?
    puts "Thoughts tokens: #{response.thoughts_token_count || 'N/A'}"
    puts "Signature present: #{response.has_thought_signature? ? 'yes' : 'no'}"
    puts "Model version: #{response.model_version}"
    puts "Gemini 3 model: #{response.gemini_3?}"

    if response.function_calls.any?
      fc = response.function_calls.first
      puts "\nFunction call detected:"
      puts "  Function name: #{fc['name']}"
      puts "  Arguments: #{fc['args']}"

      if response.has_thought_signature?
        puts "\n--- Continuation request with Signature ---"

        # Simulate function result
        stock_result = {
          symbol: "7203.T",
          price: 2850,
          currency: "JPY",
          change: "+1.2%"
        }

        # Build continuation contents using FunctionCallingHelper
        contents = Gemini::FunctionCallingHelper.build_continuation(
          original_contents: [
            { role: "user", parts: [{ text: "What is the stock price of Toyota (7203.T)?" }] }
          ],
          model_response: response,
          function_responses: [
            { name: fc['name'], response: stock_result }
          ]
        )

        # Verify Signature is included
        model_parts = contents[1][:parts]
        puts "Signature included in continuation: #{model_parts.first.key?(:thoughtSignature) ? 'yes' : 'no'}"

        # Continuation request
        final_response = client.chat(parameters: {
          model: MODEL,
          contents: contents,
          tools: [tools.to_h],
          thinking_level: :medium
        })

        if final_response.success?
          puts "\nFinal answer:"
          puts final_response.text
        else
          puts "Continuation request error: #{final_response.error}"
        end
      else
        puts "\nWarning: Could not retrieve Signature"
      end
    else
      puts "\nAnswer (no function call):"
      puts response.text
    end
  else
    puts "Error: #{response.error}"
  end

  # ============================================================
  # Demo 3: Complex Reasoning Task (high level)
  # ============================================================
  puts "\n\n### Demo 3: Complex Reasoning Task ###\n"
  puts "Solving a complex problem with thinking_level: high"
  puts "-" * 40

  response = client.generate_content(
    "Please solve this puzzle:\n" \
    "Five friends (A, B, C, D, E) are standing in a row.\n" \
    "- A is not next to B\n" \
    "- C is to the right of D\n" \
    "- E is next to A\n" \
    "- B is to the left of C\n" \
    "What is the order of all five friends?",
    model: MODEL,
    thinking_level: :high
  )

  if response.success?
    puts "Thoughts tokens: #{response.thoughts_token_count || 'N/A'}"
    puts "\nAnswer:"
    puts response.text
  else
    puts "Error: #{response.error}"
  end

  puts "\n" + "=" * 60
  puts "Demo completed"
  puts "=" * 60

rescue StandardError => e
  puts "\nAn error occurred: #{e.message}"
  puts e.backtrace.first(5).join("\n") if ENV["DEBUG"]
end
