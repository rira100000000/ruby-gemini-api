#!/usr/bin/env ruby
# frozen_string_literal: true

# デモ: Gemini Live API - Function Calling
#
# 注意: 現時点で Function Calling が確実に動作する Live API のモデルは、
# native-audio プレビューモデル + AUDIO モダリティの組み合わせのみです。
# 公式ドキュメントが推奨する gemini-2.5-flash-live-preview は
# bidiGenerateContent エンドポイントにまだデプロイされておらず、
# gemini-3.1-flash-live-preview は内部エラーになります。
# そのため本デモは AUDIO モダリティで動作し、応答音声は WAV に書き出すと
# 同時に sox の `play` コマンドが利用可能であれば再生します。
#
# 使い方:
#   export GEMINI_API_KEY=your_api_key
#   ruby demo/live_function_calling_demo_ja.rb

require "bundler/setup"
require "gemini"
require "base64"
require "tempfile"

api_key = ENV["GEMINI_API_KEY"]
unless api_key
  puts "エラー: 環境変数 GEMINI_API_KEY が設定されていません"
  exit 1
end

client = Gemini::Client.new(api_key)

# Function tool を定義
tools = [
  {
    functionDeclarations: [
      {
        name: "get_weather",
        description: "指定した場所の現在の天気を取得します",
        parameters: {
          type: "object",
          properties: {
            location: { type: "string", description: "都市名（例: 東京、ニューヨーク）" },
            unit: {
              type: "string",
              enum: %w[celsius fahrenheit],
              description: "温度の単位"
            }
          },
          required: ["location"]
        }
      },
      {
        name: "get_time",
        description: "指定したタイムゾーンの現在時刻を取得します",
        parameters: {
          type: "object",
          properties: {
            timezone: { type: "string", description: "タイムゾーン（例: Asia/Tokyo, America/New_York）" }
          },
          required: ["timezone"]
        }
      }
    ]
  }
]

# 関数の擬似実装
def get_weather(location, unit = "celsius")
  temp = rand(15..30)
  temp = (temp * 9 / 5) + 32 if unit == "fahrenheit"
  unit_symbol = unit == "celsius" ? "C" : "F"
  {
    location: location,
    temperature: temp,
    unit: unit_symbol,
    condition: ["晴れ", "曇り", "雨"].sample
  }
end

def get_time(timezone)
  require "time"
  now = Time.now.utc
  { timezone: timezone, time: now.strftime("%Y-%m-%d %H:%M:%S UTC") }
end

# 24kHz モノラル PCM-16 を WAV にラップ
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

puts "Gemini Live API に接続中（Function Calling 有効）..."

begin
  client.live.connect(
    response_modality: "AUDIO",
    voice_name: "Kore",
    tools: tools,
    system_instruction: "あなたは親切なアシスタントです。天気や時刻について聞かれたら、利用可能な関数を使ってリアルタイム情報を取得してください。応答は簡潔にしてください。"
  ) do |session|
    setup_complete = false
    audio_chunks = []

    session.on(:setup_complete) do
      setup_complete = true
      puts "接続完了。Function Calling 有効（AUDIO モダリティ）。"
      puts "-" * 40
    end

    session.on(:text) do |text|
      print text
    end

    session.on(:audio) do |data, _mime|
      audio_chunks << Base64.decode64(data)
    end

    session.on(:tool_call) do |function_calls|
      puts "\n[Tool Call を受信]"

      responses = function_calls.map do |call|
        args = call[:args] || {}
        puts "  関数名: #{call[:name]}"
        puts "  引数: #{args}"

        result = case call[:name]
                 when "get_weather"
                   get_weather(args["location"] || args[:location], args["unit"] || args[:unit] || "celsius")
                 when "get_time"
                   get_time(args["timezone"] || args[:timezone])
                 else
                   { error: "未知の関数: #{call[:name]}" }
                 end

        puts "  結果: #{result}"
        { id: call[:id], name: call[:name], response: result }
      end

      puts "[Tool Response を送信]"
      session.send_tool_response(responses)
    end

    session.on(:turn_complete) do
      pcm = audio_chunks.join
      audio_chunks.clear
      puts "\n[ターン完了; 受信した音声バイト数: #{pcm.bytesize}]"
      if pcm.bytesize.positive?
        if play_audio(pcm)
          puts "[sox で音声を再生しました]"
        else
          out = "live_fc_response_#{Time.now.to_i}.wav"
          write_wav(pcm, out)
          puts "[sox が見つからないため #{out} に書き出しました]"
        end
      end
      puts "-" * 40
    end

    session.on(:error) do |error|
      puts "\nエラー: #{error.message}"
    end

    session.on(:close) do |code, reason|
      puts "\n接続終了。Code: #{code}, Reason: #{reason}"
    end

    # セットアップ完了を待つ
    timeout = 10
    elapsed = 0
    until setup_complete || elapsed >= timeout
      sleep 0.1
      elapsed += 0.1
    end

    unless setup_complete
      puts "エラー: タイムアウト #{timeout}秒以内にセットアップが完了しませんでした"
      exit 1
    end

    puts "あなた: 東京の天気はどう？"
    session.send_text("東京の天気はどう？")
    sleep 18

    puts "\nあなた: ニューヨークは今何時？"
    session.send_text("ニューヨークは今何時？")
    sleep 18
  end
rescue Interrupt
  puts "\nユーザー操作により中断"
rescue StandardError => e
  puts "エラー: #{e.class}: #{e.message}"
  puts e.backtrace.first(5).join("\n")
end

puts "\nデモが完了しました。"
