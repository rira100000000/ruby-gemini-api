#!/usr/bin/env ruby
# frozen_string_literal: true

# Demo: Gemini Live API - Text Conversation
#
# This demo shows how to use the Live API for real-time text conversations.
#
# Usage:
#   export GEMINI_API_KEY=your_api_key
#   ruby demo/live_text_demo.rb

require "bundler/setup"
require "gemini"

api_key = ENV["GEMINI_API_KEY"]
unless api_key
  puts "Error: GEMINI_API_KEY environment variable not set"
  exit 1
end

client = Gemini::Client.new(api_key)

puts "Connecting to Gemini Live API..."

begin
  client.live.connect(
    model: "gemini-2.0-flash-live-001",
    response_modality: "TEXT",
    system_instruction: "You are a helpful and concise assistant. Keep responses brief."
  ) do |session|
    received_text = ""
    setup_complete = false

    session.on(:setup_complete) do
      setup_complete = true
      puts "Connected! Session is ready."
      puts "-" * 40
    end

    session.on(:text) do |text|
      received_text += text
      print text
    end

    session.on(:turn_complete) do
      puts "\n" + "-" * 40
    end

    session.on(:error) do |error|
      puts "\nError: #{error.message}"
    end

    session.on(:close) do |code, reason|
      puts "\nConnection closed. Code: #{code}, Reason: #{reason}"
    end

    # Wait for setup to complete
    timeout = 10
    elapsed = 0
    until setup_complete || elapsed >= timeout
      sleep 0.1
      elapsed += 0.1
    end

    unless setup_complete
      puts "Error: Setup did not complete within #{timeout} seconds"
      exit 1
    end

    # Send a message
    puts "You: What is the capital of Japan?"
    session.send_text("What is the capital of Japan?")

    # Wait for response
    sleep 5

    puts "\n"
    puts "You: Tell me a fun fact about it."
    session.send_text("Tell me a fun fact about it.")

    # Wait for response
    sleep 5
  end
rescue Interrupt
  puts "\nInterrupted by user"
rescue => e
  puts "Error: #{e.class}: #{e.message}"
  puts e.backtrace.first(5).join("\n")
end

puts "\nDemo completed."
