#!/usr/bin/env ruby
# frozen_string_literal: true

# Demo: Gemini Live API - Function Calling
#
# Note: As of writing, the only Live API model on which function calling is
# verified to work end-to-end is the native-audio preview model with the
# AUDIO response modality. The "gemini-2.5-flash-live-preview" model that
# the public docs list as supporting tools is not yet deployed on the
# bidiGenerateContent endpoint, and "gemini-3.1-flash-live-preview" returns
# an internal error. This demo therefore uses AUDIO modality and writes the
# spoken response to a WAV file (and plays it through sox `play` if
# available).
#
# Usage:
#   export GEMINI_API_KEY=your_api_key
#   ruby demo/live_function_calling_demo.rb

require "bundler/setup"
require "gemini"
require "base64"
require "tempfile"

api_key = ENV["GEMINI_API_KEY"]
unless api_key
  puts "Error: GEMINI_API_KEY environment variable not set"
  exit 1
end

client = Gemini::Client.new(api_key)

# Function tool definitions
tools = [
  {
    functionDeclarations: [
      {
        name: "get_weather",
        description: "Get the current weather for a location",
        parameters: {
          type: "object",
          properties: {
            location: { type: "string", description: "City name, e.g. Tokyo" },
            unit: {
              type: "string",
              enum: %w[celsius fahrenheit],
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
            timezone: { type: "string", description: "Timezone, e.g. Asia/Tokyo" }
          },
          required: ["timezone"]
        }
      }
    ]
  }
]

# Simulated function implementations
def get_weather(location, unit = "celsius")
  temp = rand(15..30)
  temp = (temp * 9 / 5) + 32 if unit == "fahrenheit"
  unit_symbol = unit == "celsius" ? "C" : "F"
  {
    location: location,
    temperature: temp,
    unit: unit_symbol,
    condition: %w[sunny cloudy rainy].sample
  }
end

def get_time(timezone)
  require "time"
  now = Time.now.utc
  { timezone: timezone, time: now.strftime("%Y-%m-%d %H:%M:%S UTC") }
end

# Wrap raw 24kHz mono PCM-16 chunks into a WAV file
def write_wav(pcm_bytes, path, sample_rate: 24000)
  data_size = pcm_bytes.bytesize
  byte_rate = sample_rate * 2 # 16-bit mono
  header = +"RIFF"
  header << [36 + data_size].pack("V")
  header << "WAVE"
  header << "fmt " << [16, 1, 1, sample_rate, byte_rate, 2, 16].pack("VvvVVvv")
  header << "data" << [data_size].pack("V")
  File.binwrite(path, header + pcm_bytes)
end

def play_audio(pcm_bytes)
  return false if pcm_bytes.empty?
  Tempfile.create(["gemini-fc", ".wav"]) do |tmp|
    write_wav(pcm_bytes, tmp.path)
    if system("which play > /dev/null 2>&1")
      system("play", "-q", tmp.path, out: File::NULL, err: File::NULL)
      return true
    end
  end
  false
end

puts "Connecting to Gemini Live API with Function Calling..."

begin
  client.live.connect(
    response_modality: "AUDIO",
    voice_name: "Kore",
    tools: tools,
    system_instruction: "You are a helpful assistant. Use the available functions when asked about weather or time. Keep replies brief."
  ) do |session|
    setup_complete = false
    audio_chunks = []

    session.on(:setup_complete) do
      setup_complete = true
      puts "Connected. Function calling enabled (AUDIO modality)."
      puts "-" * 40
    end

    session.on(:text) do |text|
      print text
    end

    session.on(:audio) do |data, _mime|
      audio_chunks << Base64.decode64(data)
    end

    session.on(:tool_call) do |function_calls|
      puts "\n[Tool Call Received]"

      responses = function_calls.map do |call|
        args = call[:args] || {}
        puts "  Function: #{call[:name]}"
        puts "  Args: #{args}"

        result = case call[:name]
                 when "get_weather"
                   get_weather(args["location"] || args[:location], args["unit"] || args[:unit] || "celsius")
                 when "get_time"
                   get_time(args["timezone"] || args[:timezone])
                 else
                   { error: "Unknown function: #{call[:name]}" }
                 end

        puts "  Result: #{result}"
        { id: call[:id], name: call[:name], response: result }
      end

      puts "[Sending Tool Response]"
      session.send_tool_response(responses)
    end

    session.on(:turn_complete) do
      pcm = audio_chunks.join
      audio_chunks.clear
      puts "\n[Turn complete; audio bytes received: #{pcm.bytesize}]"
      if pcm.bytesize.positive?
        if play_audio(pcm)
          puts "[Audio played via sox]"
        else
          out = "live_fc_response_#{Time.now.to_i}.wav"
          write_wav(pcm, out)
          puts "[sox not found; wrote audio to #{out}]"
        end
      end
      puts "-" * 40
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
      puts "Error: Setup did not complete in #{timeout}s"
      exit 1
    end

    puts "You: What's the weather like in Tokyo?"
    session.send_text("What's the weather like in Tokyo?")
    sleep 18

    puts "\nYou: What time is it in New York?"
    session.send_text("What time is it in New York?")
    sleep 18
  end
rescue Interrupt
  puts "\nInterrupted by user"
rescue StandardError => e
  puts "Error: #{e.class}: #{e.message}"
  puts e.backtrace.first(5).join("\n")
end

puts "\nDemo completed."
