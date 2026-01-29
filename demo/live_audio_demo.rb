#!/usr/bin/env ruby
# frozen_string_literal: true

# Demo: Gemini Live API - Audio Conversation
#
# Real-time voice conversation with Gemini using microphone and speaker.
#
# Requirements:
#   - sox (for rec/play commands)
#   - PulseAudio (for WSL2)
#
# Usage:
#   export GEMINI_API_KEY=your_api_key
#   ruby demo/live_audio_demo.rb

require "bundler/setup"
require "gemini"
require "base64"
require "tempfile"

class AudioPlayer
  def initialize(sample_rate: 24000)
    @sample_rate = sample_rate
    @chunks = []
    @mutex = Mutex.new
  end

  def add_chunk(base64_data)
    @mutex.synchronize { @chunks << base64_data }
  end

  def clear
    @mutex.synchronize { @chunks.clear }
  end

  def play_all
    chunks_to_play = @mutex.synchronize { @chunks.dup }
    return if chunks_to_play.empty?

    combined_pcm = chunks_to_play.map { |c| Base64.decode64(c) }.join

    temp = Tempfile.new(['audio', '.raw'])
    temp.binmode
    temp.write(combined_pcm)
    temp.close

    system("play", "-q", "-r", @sample_rate.to_s, "-b", "16", "-c", "1",
           "-e", "signed-integer", "-t", "raw", temp.path,
           out: File::NULL, err: File::NULL)

    temp.unlink
    @mutex.synchronize { @chunks.clear }
  end

  def chunk_count
    @mutex.synchronize { @chunks.size }
  end
end

class AudioRecorder
  SAMPLE_RATE = 16000

  # VAD付き録音: 話し終わって silence_duration 秒無音で自動停止
  def record_with_vad(max_duration: 15, silence_duration: 1.0, threshold: "1%")
    temp_file = Tempfile.new(['recording', '.raw'])
    temp_file.close

    # silence effect: 最初の無音スキップ + 末尾の無音で停止
    system("timeout", max_duration.to_s,
           "rec", "-q", "-r", SAMPLE_RATE.to_s, "-b", "16", "-c", "1",
           "-e", "signed-integer", "-t", "raw", temp_file.path,
           "silence", "1", "0.1", threshold,  # 音声開始まで待機
           "1", silence_duration.to_s, threshold,  # 無音で停止
           out: File::NULL, err: File::NULL)

    pcm_data = File.binread(temp_file.path)
    temp_file.unlink
    pcm_data
  end

  # 固定時間録音
  def record(duration)
    temp_file = Tempfile.new(['recording', '.raw'])
    temp_file.close

    system("rec", "-q", "-r", SAMPLE_RATE.to_s, "-b", "16", "-c", "1",
           "-e", "signed-integer", "-t", "raw", temp_file.path,
           "trim", "0", duration.to_s, out: File::NULL, err: File::NULL)

    pcm_data = File.binread(temp_file.path)
    temp_file.unlink
    pcm_data
  end
end

def send_audio_message(session, pcm_data)
  conn = session.instance_variable_get(:@connection)
  encoded = Base64.strict_encode64(pcm_data)

  # 手動VAD: activityStart → 音声 → activityEnd
  conn.send({ realtimeInput: { activityStart: {} } })

  conn.send({
    realtimeInput: {
      mediaChunks: [{
        mimeType: "audio/pcm;rate=16000",
        data: encoded
      }]
    }
  })

  conn.send({ realtimeInput: { activityEnd: {} } })
end

# Main
api_key = ENV["GEMINI_API_KEY"]
unless api_key
  puts "Error: GEMINI_API_KEY environment variable not set"
  exit 1
end

puts "=" * 50
puts "Gemini Live API - Audio Conversation"
puts "=" * 50
puts
puts "操作方法:"
puts "  Enter      → 録音開始（話し終わると自動送信）"
puts "  quit       → 終了"
puts "  text:〇〇  → テキストで送信"
puts
puts "接続中..."

client = Gemini::Client.new(api_key)
player = AudioPlayer.new
recorder = AudioRecorder.new

begin
  client.live.connect(
    model: "gemini-2.5-flash-native-audio-preview-12-2025",
    response_modality: "AUDIO",
    voice_name: "Kore",
    system_instruction: "You are a friendly voice assistant. Keep responses brief and natural. Match the language of the user.",
    automatic_activity_detection: false  # 手動VADモード
  ) do |session|
    setup_complete = false
    waiting_response = false

    session.on(:setup_complete) do
      setup_complete = true
      puts "接続完了！"
      puts "-" * 50
    end

    session.on(:audio) do |data, _|
      player.add_chunk(data)
      print "."
    end

    session.on(:turn_complete) do
      count = player.chunk_count
      puts " [#{count} chunks]" if count > 0
      player.play_all
      waiting_response = false
    end

    session.on(:interrupted) do
      puts "\n[中断]"
      player.clear
      waiting_response = false
    end

    session.on(:error) do |error|
      puts "\n[Error] #{error.message}" unless error.message.include?("stream")
    end

    # Wait for setup
    15.times do
      break if setup_complete
      sleep 1
    end

    unless setup_complete
      puts "接続タイムアウト"
      exit 1
    end

    loop do
      # レスポンス待ち中はスキップ
      if waiting_response
        sleep 0.1
        next
      end

      print "> "
      input = gets&.chomp

      break if input.nil? || %w[quit exit q].include?(input&.downcase)

      if input.start_with?("text:")
        text = input[5..].strip
        next if text.empty?
        puts "テキスト送信中..."
        waiting_response = true
        session.send_text(text)
        next
      end

      # VAD付き録音（話し終わると自動停止）
      puts ">>> 話してください（1秒無音で自動送信）<<<"
      pcm_data = recorder.record_with_vad

      if pcm_data.bytesize < 8000  # < 0.25 second
        puts "録音が短すぎます。もう一度試してください。"
        next
      end

      duration = pcm_data.bytesize / 32000.0
      puts "録音完了 (#{duration.round(1)}秒)"

      puts "送信中..."
      waiting_response = true
      send_audio_message(session, pcm_data)
    end
  end
rescue Interrupt
  puts "\nBye!"
rescue => e
  puts "Error: #{e.class}: #{e.message}"
end

puts "終了しました"
