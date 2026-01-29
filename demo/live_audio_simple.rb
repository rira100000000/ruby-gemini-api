#!/usr/bin/env ruby
# frozen_string_literal: true

# Demo: Gemini Live API - Simple Audio Response
#
# Send text, receive audio response. No microphone needed.
#
# Usage:
#   export GEMINI_API_KEY=your_api_key
#   ruby demo/live_audio_simple.rb "Hello, how are you?"

require "bundler/setup"
require "gemini"
require "base64"
require "tempfile"

def play_audio(pcm_data, sample_rate = 24000)
  temp = Tempfile.new(['audio', '.raw'])
  temp.binmode
  temp.write(pcm_data)
  temp.close

  system("play", "-q", "-r", sample_rate.to_s, "-b", "16", "-c", "1",
         "-e", "signed-integer", "-t", "raw", temp.path,
         out: File::NULL, err: File::NULL)

  temp.unlink
end

api_key = ENV["GEMINI_API_KEY"]
unless api_key
  puts "Error: GEMINI_API_KEY not set"
  exit 1
end

message = ARGV[0] || "こんにちは！"
puts "Message: #{message}"
puts "Connecting..."

client = Gemini::Client.new(api_key)
audio_chunks = []

begin
  client.live.connect(
    model: "gemini-2.5-flash-native-audio-preview-12-2025",
    response_modality: "AUDIO",
    voice_name: "Kore"
  ) do |session|
    done = false

    session.on(:setup_complete) { puts "Connected!" }
    session.on(:audio) { |data, _| audio_chunks << data; print "." }
    session.on(:turn_complete) { puts " Done!"; done = true }
    session.on(:error) { |e| puts "Error: #{e.message}" unless e.message.include?("stream closed") }

    # Wait for setup
    Timeout.timeout(10) { sleep 0.1 until session.setup_complete? }

    session.send_text(message)

    # Wait for response
    Timeout.timeout(30) { sleep 0.1 until done }
  end
rescue Timeout::Error
  puts "\nTimeout"
rescue => e
  puts "\nError: #{e.message}"
end

if audio_chunks.any?
  combined_pcm = audio_chunks.map { |c| Base64.decode64(c) }.join
  duration = combined_pcm.bytesize / 48000.0
  puts "Playing #{audio_chunks.size} chunks (#{duration.round(1)}s)..."
  play_audio(combined_pcm)
  puts "Done!"
else
  puts "No audio received."
end
