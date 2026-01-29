#!/usr/bin/env ruby
# frozen_string_literal: true

# Demo: Gemini Live API - Real-time Audio Conversation
#
# Low-latency voice conversation with streaming send/receive.
#
# Requirements:
#   - sox (for rec/play commands)
#   - PulseAudio (for WSL2)
#
# Usage:
#   export GEMINI_API_KEY=your_api_key
#   ruby demo/live_audio_demo.rb

require "bundler/setup"
require "websocket-client-simple"
require "json"
require "base64"
require "open3"

class LiveAudioSession
  CHUNK_SIZE = 3200  # 100ms at 16kHz 16bit mono
  RECORD_DURATION = 5  # max seconds

  def initialize(api_key)
    @api_key = api_key
    @ws = nil
    @setup_done = false
    @responding = false
    @play_io = nil
  end

  def start
    connect
    wait_for_setup

    puts "-" * 50
    main_loop
  ensure
    cleanup
  end

  private

  def connect
    url = "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=#{@api_key}"

    @ws = WebSocket::Client::Simple.connect(url)
    session = self

    @ws.on :open do
      session.send_setup
    end

    @ws.on :message do |msg|
      session.handle_message(msg.data)
    end

    @ws.on :error do |e|
      puts "[Error] #{e}" unless e.to_s.include?("stream")
    end
  end

  def send_setup
    @ws.send({
      setup: {
        model: "models/gemini-2.5-flash-native-audio-preview-12-2025",
        generationConfig: {
          responseModalities: ["AUDIO"],
          speechConfig: {
            voiceConfig: { prebuiltVoiceConfig: { voiceName: "Kore" } }
          }
        },
        realtimeInputConfig: {
          automaticActivityDetection: { disabled: true }
        }
      }
    }.to_json)
  end

  def handle_message(data)
    parsed = JSON.parse(data) rescue nil
    return unless parsed

    if parsed["setupComplete"]
      @setup_done = true
    elsif parsed["serverContent"]
      handle_server_content(parsed["serverContent"])
    end
  end

  def handle_server_content(content)
    if content["interrupted"]
      puts "\n[中断]"
      stop_playback
      @responding = false
      return
    end

    parts = content.dig("modelTurn", "parts") || []
    parts.each do |part|
      if part["inlineData"]
        # ストリーミング再生
        start_playback unless @play_io
        pcm = Base64.decode64(part["inlineData"]["data"])
        @play_io.write(pcm) rescue nil
        print "."
      end
    end

    if content["turnComplete"]
      puts " [完了]"
      stop_playback
      @responding = false
    end
  end

  def start_playback
    @play_io = IO.popen(
      ["play", "-q", "-r", "24000", "-b", "16", "-c", "1", "-e", "signed-integer", "-t", "raw", "-"],
      "wb"
    )
  end

  def stop_playback
    @play_io&.close rescue nil
    @play_io = nil
  end

  def wait_for_setup
    print "接続中"
    30.times do
      if @setup_done
        puts " OK!"
        return
      end
      print "."
      sleep 0.5
    end
    raise "接続タイムアウト"
  end

  def main_loop
    loop do
      break if @responding

      print "> "
      input = gets&.chomp

      break if input.nil? || %w[quit exit q].include?(input&.downcase)

      if input.start_with?("text:")
        send_text(input[5..].strip)
      else
        record_and_send
      end

      # 応答待ち
      wait_for_response
    end
  end

  def send_text(text)
    return if text.empty?
    puts "テキスト送信..."
    @responding = true
    @ws.send({
      clientContent: {
        turns: [{ role: "user", parts: [{ text: text }] }],
        turnComplete: true
      }
    }.to_json)
  end

  def record_and_send
    puts ">>> 話してください（最大#{RECORD_DURATION}秒、無音で自動終了）<<<"
    @responding = true

    # activityStart
    @ws.send({ realtimeInput: { activityStart: {} } }.to_json)

    # リアルタイム録音・送信
    sent = 0
    Open3.popen3(
      "rec", "-q", "-r", "16000", "-b", "16", "-c", "1", "-e", "signed-integer", "-t", "raw", "-",
      "silence", "1", "0.3", "0.5%", "1", "1.5", "0.5%",
      "trim", "0", RECORD_DURATION.to_s
    ) do |stdin, stdout, stderr, thread|
      stdin.close
      while (chunk = stdout.read(CHUNK_SIZE))
        break if chunk.empty?
        @ws.send({
          realtimeInput: {
            mediaChunks: [{ mimeType: "audio/pcm;rate=16000", data: Base64.strict_encode64(chunk) }]
          }
        }.to_json)
        sent += chunk.bytesize
        print "s"
      end
    end

    puts "\n送信完了 (#{(sent / 32000.0).round(1)}秒)"

    # activityEnd
    @ws.send({ realtimeInput: { activityEnd: {} } }.to_json)
  end

  def wait_for_response
    60.times do
      break unless @responding
      sleep 0.5
    end
  end

  def cleanup
    stop_playback
    @ws&.close rescue nil
  end
end

# Main
api_key = ENV["GEMINI_API_KEY"]
unless api_key
  puts "Error: GEMINI_API_KEY not set"
  exit 1
end

puts "=" * 50
puts "Gemini Live API - Real-time Audio Conversation"
puts "=" * 50
puts
puts "操作方法:"
puts "  Enter      → 録音開始（無音で自動送信）"
puts "  text:〇〇  → テキストで送信"
puts "  quit       → 終了"
puts

begin
  LiveAudioSession.new(api_key).start
rescue Interrupt
  puts "\nBye!"
rescue => e
  puts "Error: #{e.message}"
end
