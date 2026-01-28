#!/usr/bin/env ruby
# frozen_string_literal: true

# Gemini 3 Thinking機能デモ
#
# Gemini 3では thinking_level（:minimal, :low, :medium, :high）を使用
# Function Calling時はThought Signatureが必須
#
# 使用方法:
#   ruby demo/thinking_gemini3_demo_ja.rb
#
# 環境変数:
#   GEMINI_API_KEY - Gemini APIキー（必須）

require 'bundler/setup'
require 'gemini'

api_key = ENV['GEMINI_API_KEY'] || raise("GEMINI_API_KEY環境変数を設定してください")

MODEL = "gemini-3-flash-preview"

begin
  puts "=" * 60
  puts "Gemini 3 Thinking機能 デモ"
  puts "モデル: #{MODEL}"
  puts "=" * 60

  client = Gemini::Client.new(api_key)

  # ============================================================
  # デモ1: thinking_level の比較
  # ============================================================
  puts "\n### デモ1: thinking_level の比較 ###\n"
  puts "同じ質問を異なるthinking_levelで比較"
  puts "-" * 40

  prompt = "AIの倫理的な課題について、主な論点を3つ挙げて説明してください。"

  %i[minimal low medium high].each do |level|
    puts "\n[thinking_level: #{level}]"

    response = client.generate_content(
      prompt,
      model: MODEL,
      thinking_level: level
    )

    if response.success?
      puts "思考トークン: #{response.thoughts_token_count || 'N/A'}"
      puts "回答（最初の150文字）:"
      text = response.text || ""
      puts text[0..150] + (text.length > 150 ? "..." : "")
    else
      puts "エラー: #{response.error}"
    end
  end

  # ============================================================
  # デモ2: Function Calling + Thinking（Gemini 3）
  # ============================================================
  puts "\n\n### デモ2: Function Calling + Thinking（Gemini 3） ###\n"
  puts "Gemini 3ではFunction Calling継続時にSignatureが必須"
  puts "-" * 40

  # ツール定義
  tools = Gemini::ToolDefinition.new do
    function :get_stock_price, description: "株価を取得します" do
      property :symbol, type: :string, description: "ティッカーシンボル", required: true
      property :exchange, type: :string, description: "取引所"
    end

    function :get_weather, description: "天気を取得します" do
      property :location, type: :string, description: "場所", required: true
    end
  end

  puts "\n初回リクエスト..."
  response = client.generate_content(
    "トヨタ自動車（7203.T）の株価を教えてください。",
    model: MODEL,
    tools: tools,
    thinking_level: :medium
  )

  if response.success?
    puts "思考トークン: #{response.thoughts_token_count || 'N/A'}"
    puts "Signature存在: #{response.has_thought_signature? ? 'あり' : 'なし'}"
    puts "モデルバージョン: #{response.model_version}"
    puts "Gemini 3系: #{response.gemini_3?}"

    if response.function_calls.any?
      fc = response.function_calls.first
      puts "\n関数呼び出し検出:"
      puts "  関数名: #{fc['name']}"
      puts "  引数: #{fc['args']}"

      if response.has_thought_signature?
        puts "\n--- Signatureを使って継続リクエスト ---"

        # 関数の結果をシミュレート
        stock_result = {
          symbol: "7203.T",
          price: 2850,
          currency: "JPY",
          change: "+1.2%"
        }

        # FunctionCallingHelperで継続用contentsを構築
        contents = Gemini::FunctionCallingHelper.build_continuation(
          original_contents: [
            { role: "user", parts: [{ text: "トヨタ自動車（7203.T）の株価を教えてください。" }] }
          ],
          model_response: response,
          function_responses: [
            { name: fc['name'], response: stock_result }
          ]
        )

        # Signatureが含まれていることを確認
        model_parts = contents[1][:parts]
        puts "継続リクエストにSignature含む: #{model_parts.first.key?(:thoughtSignature) ? 'はい' : 'いいえ'}"

        # 継続リクエスト
        final_response = client.chat(parameters: {
          model: MODEL,
          contents: contents,
          tools: [tools.to_h],
          thinking_level: :medium
        })

        if final_response.success?
          puts "\n最終回答:"
          puts final_response.text
        else
          puts "継続リクエストエラー: #{final_response.error}"
        end
      else
        puts "\n警告: Signatureが取得できませんでした"
      end
    else
      puts "\n回答（関数呼び出しなし）:"
      puts response.text
    end
  else
    puts "エラー: #{response.error}"
  end

  # ============================================================
  # デモ3: 複雑な推論タスク（high レベル）
  # ============================================================
  puts "\n\n### デモ3: 複雑な推論タスク ###\n"
  puts "thinking_level: high で複雑な問題を解く"
  puts "-" * 40

  response = client.generate_content(
    "次のパズルを解いてください：\n" \
    "5人の友人（A, B, C, D, E）が一列に並んでいます。\n" \
    "- AはBの隣にいない\n" \
    "- CはDの右側にいる\n" \
    "- EはAの隣にいる\n" \
    "- BはCの左側にいる\n" \
    "全員の並び順を答えてください。",
    model: MODEL,
    thinking_level: :high
  )

  if response.success?
    puts "思考トークン: #{response.thoughts_token_count || 'N/A'}"
    puts "\n回答:"
    puts response.text
  else
    puts "エラー: #{response.error}"
  end

  puts "\n" + "=" * 60
  puts "デモ完了"
  puts "=" * 60

rescue StandardError => e
  puts "\nエラーが発生しました: #{e.message}"
  puts e.backtrace.first(5).join("\n") if ENV["DEBUG"]
end
