#!/usr/bin/env ruby
# frozen_string_literal: true

# Code Execution Demo
#
# Code Execution lets Gemini generate and run Python code when calculation or
# data processing is useful. The final answer is still available as response.text,
# and the generated code / execution output can be inspected separately.
#
# Usage:
#   ruby demo/code_execution_demo.rb
#
# Environment variables:
#   GEMINI_API_KEY - Gemini API key (required)
#   GEMINI_MODEL   - Optional model override (default: gemini-3.5-flash)

require 'bundler/setup'
require 'gemini'

api_key = ENV['GEMINI_API_KEY'] || raise("Please set the GEMINI_API_KEY environment variable")
model = ENV['GEMINI_MODEL'] || "gemini-3.5-flash"

begin
  puts "=" * 60
  puts "Gemini Code Execution Demo"
  puts "Model: #{model}"
  puts "=" * 60
  puts
  puts "What this demo shows:"
  puts "- Add code_execution: true to generate_content"
  puts "- Gemini can run Python for calculations"
  puts "- You can read the final answer, generated code, and execution output"
  puts

  client = Gemini::Client.new(api_key)

  prompt = "Calculate the sum of the first 50 prime numbers. Use Python code to verify the result, then explain the answer briefly."

  puts "Prompt:"
  puts prompt
  puts
  puts "Requesting Gemini with code_execution: true..."
  puts

  response = client.generate_content(
    prompt,
    model: model,
    code_execution: true
  )

  unless response.success?
    puts "Error: #{response.error || 'Unknown error'}"
    exit 1
  end

  puts "Final answer:"
  puts response.text
  puts

  if response.code_execution?
    puts "Generated Python code:"
    puts "-" * 40
    puts response.executable_code || "(no code text returned)"
    puts "-" * 40
    puts

    puts "Execution outcome: #{response.code_execution_outcome || 'unknown'}"
    puts

    puts "Execution output:"
    puts "-" * 40
    puts response.code_execution_output || "(no execution output returned)"
    puts "-" * 40
  else
    puts "No Code Execution parts were returned."
    puts "The model may have answered without needing to run code."
  end

  puts
  puts "=" * 60
  puts "Demo completed"
  puts "=" * 60
rescue StandardError => e
  puts "\nAn error occurred: #{e.message}"
  puts e.backtrace.first(5).join("\n") if ENV["DEBUG"]
end
