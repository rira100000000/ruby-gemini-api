#!/usr/bin/env ruby
# frozen_string_literal: true

# デモ: Gemini Live API - Function Calling
#
# Live API で Function Calling を使う方法を示すデモです。
#
# 使い方:
#   export GEMINI_API_KEY=your_api_key
#   ruby demo/live_function_calling_demo_ja.rb

require "bundler/setup"
require "gemini"

api_key = ENV["GEMINI_API_KEY"]
unless api_key
  puts "エラー: 環境変数 GEMINI_API_KEY が設定されていません"
  exit 1
end

client = Gemini::Client.new(api_key)

# Function tools を定義
tools = [
  {
    functionDeclarations: [
      {
        name: "get_weather",
        description: "指定した場所の現在の天気を取得します",
        parameters: {
          type: "object",
          properties: {
            location: {
              type: "string",
              description: "都市名（例: 東京、ニューヨーク）"
            },
            unit: {
              type: "string",
              enum: ["celsius", "fahrenheit"],
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
            timezone: {
              type: "string",
              description: "タイムゾーン（例: Asia/Tokyo, America/New_York）"
            }
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

puts "Gemini Live API に接続中（Function Calling 有効）..."

begin
  client.live.connect(
    model: "gemini-2.5-flash-live-preview",
    response_modality: "TEXT",
    tools: tools,
    system_instruction: "あなたは親切なアシスタントです。天気や時刻について質問されたら、利用可能な関数を使ってリアルタイム情報を取得してください。"
  ) do |session|
    setup_complete = false

    session.on(:setup_complete) do
      setup_complete = true
      puts "接続完了。Function Calling が有効になりました。"
      puts "-" * 40
    end

    session.on(:text) do |text|
      print text
    end

    session.on(:turn_complete) do
      puts "\n" + "-" * 40
    end

    session.on(:tool_call) do |function_calls|
      puts "\n[Tool Call を受信]"

      responses = function_calls.map do |call|
        puts "  関数名: #{call[:name]}"
        puts "  引数: #{call[:args]}"

        result = case call[:name]
                 when "get_weather"
                   get_weather(
                     call[:args]["location"] || call[:args][:location],
                     call[:args]["unit"] || call[:args][:unit] || "celsius"
                   )
                 when "get_time"
                   get_time(call[:args]["timezone"] || call[:args][:timezone])
                 else
                   { error: "未知の関数: #{call[:name]}" }
                 end

        puts "  結果: #{result}"

        {
          id: call[:id],
          name: call[:name],
          response: result
        }
      end

      puts "[Tool Response を送信]"
      session.send_tool_response(responses)
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
      puts "エラー: タイムアウト内にセットアップが完了しませんでした"
      exit 1
    end

    # 天気を聞く
    puts "あなた: 東京の天気はどう？"
    session.send_text("東京の天気はどう？")
    sleep 8

    puts "\n"
    puts "あなた: ニューヨークは今何時？"
    session.send_text("ニューヨークは今何時？")
    sleep 8
  end
rescue Interrupt
  puts "\nユーザー操作により中断"
rescue StandardError => e
  puts "エラー: #{e.class}: #{e.message}"
  puts e.backtrace.first(5).join("\n")
end

puts "\nデモが完了しました。"
