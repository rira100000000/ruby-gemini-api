#!/usr/bin/env ruby
# frozen_string_literal: true

# Gemini Thinking Feature Demo
#
# Usage:
#   ruby demo/thinking_demo.rb
#
# Environment variables:
#   GEMINI_API_KEY - Gemini API key (required)

require "bundler/setup"
require "gemini"

api_key = ENV["GEMINI_API_KEY"] || raise("Please set the GEMINI_API_KEY environment variable")

begin
  puts "=" * 60
  puts "Gemini Thinking Feature Demo"
  puts "=" * 60

  client = Gemini::Client.new(api_key)

  # ============================================================
  # Demo 1: Gemini 2.5 + thinking_budget
  # ============================================================
  puts "\n### Demo 1: Gemini 2.5 + thinking_budget ###\n"
  puts "Solving a complex problem with thinking_budget: 2048"
  puts "-" * 40

  response = client.generate_content(
    "Please solve this math puzzle: Three friends had dinner at a restaurant. " \
    "The bill was $30, so each paid $10. Later, the waiter realized there was " \
    "a $5 discount and came back to return $5. The three friends each took $1 " \
    "back and left $2 as a tip. So each paid $9, totaling $27. Adding the $2 " \
    "tip makes $29. Where did the remaining $1 go?",
    model: "gemini-2.5-flash",
    thinking_budget: 2048
  )

  if response.success?
    puts "\nAnswer:"
    puts response.text
    puts "\n--- Thinking Info ---"
    puts "Thoughts token count: #{response.thoughts_token_count || "N/A"}"
  else
    puts "Error: #{response.error}"
  end

  # ============================================================
  # Demo 2: Comparing thinking_budget (disabled vs enabled)
  # ============================================================
  puts "\n\n### Demo 2: Comparing thinking_budget ###\n"
  puts "Comparing the same question with thinking_budget: 0 (disabled) vs -1 (dynamic)"
  puts "-" * 40

  prompt = "Explain an efficient algorithm to calculate the 100th term of the Fibonacci sequence."

  # Thinking disabled
  puts "\n[thinking_budget: 0 (thinking disabled)]"
  response_no_think = client.generate_content(
    prompt,
    model: "gemini-2.5-flash",
    thinking_budget: 0
  )

  if response_no_think.success?
    puts "Thoughts tokens: #{response_no_think.thoughts_token_count || "none"}"
    puts "Answer (first 200 chars):"
    puts response_no_think.text[0..200] + "..."
  end

  # Thinking enabled (dynamic)
  puts "\n[thinking_budget: -1 (dynamic thinking)]"
  response_think = client.generate_content(
    prompt,
    model: "gemini-2.5-flash",
    thinking_budget: -1
  )

  if response_think.success?
    puts "Thoughts tokens: #{response_think.thoughts_token_count || "none"}"
    puts "Answer (first 200 chars):"
    puts response_think.text[0..200] + "..."
  end

  # ============================================================
  # Demo 3: Function Calling + Thinking (Gemini 2.5)
  # ============================================================
  puts "\n\n### Demo 3: Function Calling + Thinking ###\n"
  puts "Combining function calling with the Thinking feature"
  puts "-" * 40

  # Tool definition
  tools = Gemini::ToolDefinition.new do
    function :get_weather, description: "Get weather for a specified location" do
      property :location, type: :string, description: "City name", required: true
    end
  end

  response = client.generate_content(
    "What's the weather in Tokyo today?",
    model: "gemini-2.5-flash",
    tools: tools,
    thinking_budget: 1024
  )

  if response.success?
    puts "Thoughts tokens: #{response.thoughts_token_count || "none"}"
    puts "Signature present: #{response.has_thought_signature? ? "yes" : "no"}"

    if response.function_calls.any?
      fc = response.function_calls.first
      puts "\nFunction call detected:"
      puts "  Function name: #{fc["name"]}"
      puts "  Arguments: #{fc["args"]}"

      # Build continuation request using FunctionCallingHelper
      puts "\n--- Returning function result ---"

      # Simulate function result
      weather_result = {
        location: "Tokyo",
        weather: "Sunny",
        temperature: 18,
        humidity: 45
      }

      # Build continuation contents (with automatic signature attachment)
      contents = Gemini::FunctionCallingHelper.build_continuation(
        original_contents: [{ role: "user", parts: [{ text: "What's the weather in Tokyo today?" }] }],
        model_response: response,
        function_responses: [
          { name: "get_weather", response: weather_result }
        ]
      )

      # Continuation request
      final_response = client.chat(parameters: {
                                     model: "gemini-2.5-flash",
                                     contents: contents,
                                     tools: [tools.to_h],
                                     thinking_budget: 1024
                                   })

      if final_response.success?
        puts "\nFinal answer:"
        puts final_response.text
      else
        puts "Continuation request error: #{final_response.error}"
      end
    else
      puts "\nAnswer (no function call):"
      puts response.text
    end
  else
    puts "Error: #{response.error}"
  end

  # ============================================================
  # Demo 4: Response Methods Check
  # ============================================================
  puts "\n\n### Demo 4: Response Thinking Methods ###\n"
  puts "Checking various methods of the Response object"
  puts "-" * 40

  response = client.generate_content(
    "Briefly explain the features of Ruby.",
    model: "gemini-2.5-flash",
    thinking_budget: 512
  )

  if response.success?
    puts "thoughts_token_count: #{response.thoughts_token_count.inspect}"
    puts "model_version: #{response.model_version.inspect}"
    puts "gemini_3?: #{response.gemini_3?}"
    puts "thought_signatures: #{response.thought_signatures.length} item(s)"
    puts "has_thought_signature?: #{response.has_thought_signature?}"
  end

  puts "\n" + "=" * 60
  puts "Demo completed"
  puts "=" * 60
rescue StandardError => e
  puts "\nAn error occurred: #{e.message}"
  puts e.backtrace.first(5).join("\n") if ENV["DEBUG"]
end
