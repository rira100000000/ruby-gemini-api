#!/usr/bin/env ruby
# frozen_string_literal: true

# Demo: Gemini Live API - Function Calling
#
# This demo shows how to use function calling with the Live API.
#
# Usage:
#   export GEMINI_API_KEY=your_api_key
#   ruby demo/live_function_calling_demo.rb

require "bundler/setup"
require "gemini"

api_key = ENV["GEMINI_API_KEY"]
unless api_key
  puts "Error: GEMINI_API_KEY environment variable not set"
  exit 1
end

client = Gemini::Client.new(api_key)

# Define function tools
tools = [
  {
    functionDeclarations: [
      {
        name: "get_weather",
        description: "Get the current weather for a location",
        parameters: {
          type: "object",
          properties: {
            location: {
              type: "string",
              description: "The city name, e.g. Tokyo, New York"
            },
            unit: {
              type: "string",
              enum: ["celsius", "fahrenheit"],
              description: "Temperature unit"
            }
          },
          required: ["location"]
        }
      },
      {
        name: "get_time",
        description: "Get the current time for a timezone",
        parameters: {
          type: "object",
          properties: {
            timezone: {
              type: "string",
              description: "The timezone, e.g. Asia/Tokyo, America/New_York"
            }
          },
          required: ["timezone"]
        }
      }
    ]
  }
]

# Simulated function implementations
def get_weather(location, unit = "celsius")
  # In a real app, this would call a weather API
  temp = rand(15..30)
  temp = (temp * 9 / 5) + 32 if unit == "fahrenheit"
  unit_symbol = unit == "celsius" ? "C" : "F"
  {
    location: location,
    temperature: temp,
    unit: unit_symbol,
    condition: ["sunny", "cloudy", "rainy"].sample
  }
end

def get_time(timezone)
  # In a real app, this would use proper timezone handling
  require "time"
  now = Time.now.utc
  { timezone: timezone, time: now.strftime("%Y-%m-%d %H:%M:%S UTC") }
end

puts "Connecting to Gemini Live API with Function Calling..."

begin
  client.live.connect(
    model: "gemini-2.0-flash-live-001",
    response_modality: "TEXT",
    tools: tools,
    system_instruction: "You are a helpful assistant. Use the available functions to get real-time information when asked about weather or time."
  ) do |session|
    setup_complete = false

    session.on(:setup_complete) do
      setup_complete = true
      puts "Connected! Function calling enabled."
      puts "-" * 40
    end

    session.on(:text) do |text|
      print text
    end

    session.on(:turn_complete) do
      puts "\n" + "-" * 40
    end

    session.on(:tool_call) do |function_calls|
      puts "\n[Tool Call Received]"

      responses = function_calls.map do |call|
        puts "  Function: #{call[:name]}"
        puts "  Args: #{call[:args]}"

        result = case call[:name]
                 when "get_weather"
                   get_weather(
                     call[:args]["location"] || call[:args][:location],
                     call[:args]["unit"] || call[:args][:unit] || "celsius"
                   )
                 when "get_time"
                   get_time(call[:args]["timezone"] || call[:args][:timezone])
                 else
                   { error: "Unknown function: #{call[:name]}" }
                 end

        puts "  Result: #{result}"

        {
          id: call[:id],
          name: call[:name],
          response: result
        }
      end

      puts "[Sending Tool Response]"
      session.send_tool_response(responses)
    end

    session.on(:error) do |error|
      puts "\nError: #{error.message}"
    end

    session.on(:close) do |code, reason|
      puts "\nConnection closed. Code: #{code}, Reason: #{reason}"
    end

    # Wait for setup
    timeout = 10
    elapsed = 0
    until setup_complete || elapsed >= timeout
      sleep 0.1
      elapsed += 0.1
    end

    unless setup_complete
      puts "Error: Setup did not complete"
      exit 1
    end

    # Ask about weather
    puts "You: What's the weather like in Tokyo?"
    session.send_text("What's the weather like in Tokyo?")
    sleep 8

    puts "\n"
    puts "You: What time is it in New York?"
    session.send_text("What time is it in New York?")
    sleep 8
  end
rescue Interrupt
  puts "\nInterrupted by user"
rescue => e
  puts "Error: #{e.class}: #{e.message}"
  puts e.backtrace.first(5).join("\n")
end

puts "\nDemo completed."
