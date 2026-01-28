#!/usr/bin/env ruby
# frozen_string_literal: true

# Gemini Thinking機能デモ
#
# 使用方法:
#   ruby demo/thinking_demo_ja.rb
#
# 環境変数:
#   GEMINI_API_KEY - Gemini APIキー（必須）

require "bundler/setup"
require "gemini"

api_key = ENV["GEMINI_API_KEY"] || raise("GEMINI_API_KEY環境変数を設定してください")

begin
  puts "=" * 60
  puts "Gemini Thinking機能 デモ"
  puts "=" * 60

  client = Gemini::Client.new(api_key)

  # ============================================================
  # デモ1: Gemini 2.5 + thinking_budget
  # ============================================================
  puts "\n### デモ1: Gemini 2.5 + thinking_budget ###\n"
  puts "thinking_budget: 2048 で複雑な問題を解く"
  puts "-" * 40

  response = client.generate_content(
    "次の数学パズルを解いてください：3人の友人がレストランで食事をしました。" \
    "請求額は30ドルで、各自10ドルずつ払いました。後でウェイターが5ドルの " \
    "割引があったことに気づき、5ドルを返しに来ました。3人は各自1ドルずつ " \
    "受け取り、2ドルをチップとして残しました。つまり各自9ドル払ったことに " \
    "なり、合計27ドル。チップ2ドルを足すと29ドル。残りの1ドルはどこへ？",
    model: "gemini-2.5-flash",
    thinking_budget: 2048
  )

  if response.success?
    puts "\n回答:"
    puts response.text
    puts "\n--- Thinking情報 ---"
    puts "思考トークン数: #{response.thoughts_token_count || "N/A"}"
  else
    puts "エラー: #{response.error}"
  end

  # ============================================================
  # デモ2: thinking_budget の比較（無効 vs 有効）
  # ============================================================
  puts "\n\n### デモ2: thinking_budget の比較 ###\n"
  puts "同じ質問を thinking_budget: 0（無効）と -1（動的）で比較"
  puts "-" * 40

  prompt = "フィボナッチ数列の100番目の項を計算する効率的なアルゴリズムを説明してください。"

  # 思考無効
  puts "\n[thinking_budget: 0（思考無効）]"
  response_no_think = client.generate_content(
    prompt,
    model: "gemini-2.5-flash",
    thinking_budget: 0
  )

  if response_no_think.success?
    puts "思考トークン: #{response_no_think.thoughts_token_count || "なし"}"
    puts "回答（最初の200文字）:"
    puts response_no_think.text[0..200] + "..."
  end

  # 思考有効（動的）
  puts "\n[thinking_budget: -1（動的思考）]"
  response_think = client.generate_content(
    prompt,
    model: "gemini-2.5-flash",
    thinking_budget: -1
  )

  if response_think.success?
    puts "思考トークン: #{response_think.thoughts_token_count || "なし"}"
    puts "回答（最初の200文字）:"
    puts response_think.text[0..200] + "..."
  end

  # ============================================================
  # デモ3: Function Calling + Thinking（Gemini 2.5）
  # ============================================================
  puts "\n\n### デモ3: Function Calling + Thinking ###\n"
  puts "関数呼び出しとThinking機能の組み合わせ"
  puts "-" * 40

  # ツール定義
  tools = Gemini::ToolDefinition.new do
    function :get_weather, description: "指定された場所の天気を取得します" do
      property :location, type: :string, description: "都市名", required: true
    end
  end

  response = client.generate_content(
    "東京の今日の天気を教えてください。",
    model: "gemini-2.5-flash",
    tools: tools,
    thinking_budget: 1024
  )

  if response.success?
    puts "思考トークン: #{response.thoughts_token_count || "なし"}"
    puts "Signature存在: #{response.has_thought_signature? ? "あり" : "なし"}"

    if response.function_calls.any?
      fc = response.function_calls.first
      puts "\n関数呼び出し検出:"
      puts "  関数名: #{fc["name"]}"
      puts "  引数: #{fc["args"]}"

      # FunctionCallingHelperを使って継続リクエストを構築
      puts "\n--- 関数結果を返す ---"

      # 関数の結果をシミュレート
      weather_result = {
        location: "東京",
        weather: "晴れ",
        temperature: 18,
        humidity: 45
      }

      # 継続用のcontentsを構築（Signature自動付与）
      contents = Gemini::FunctionCallingHelper.build_continuation(
        original_contents: [{ role: "user", parts: [{ text: "東京の今日の天気を教えてください。" }] }],
        model_response: response,
        function_responses: [
          { name: "get_weather", response: weather_result }
        ]
      )

      # 継続リクエスト
      final_response = client.chat(parameters: {
                                     model: "gemini-2.5-flash",
                                     contents: contents,
                                     tools: [tools.to_h],
                                     thinking_budget: 1024
                                   })

      if final_response.success?
        puts "\n最終回答:"
        puts final_response.text
      else
        puts "継続リクエストエラー: #{final_response.error}"
      end
    else
      puts "\n回答（関数呼び出しなし）:"
      puts response.text
    end
  else
    puts "エラー: #{response.error}"
  end

  # ============================================================
  # デモ4: Response メソッドの確認
  # ============================================================
  puts "\n\n### デモ4: Response Thinkingメソッド ###\n"
  puts "Responseオブジェクトの各種メソッドを確認"
  puts "-" * 40

  response = client.generate_content(
    "Rubyの特徴を簡潔に説明してください。",
    model: "gemini-2.5-flash",
    thinking_budget: 512
  )

  if response.success?
    puts "thoughts_token_count: #{response.thoughts_token_count.inspect}"
    puts "model_version: #{response.model_version.inspect}"
    puts "gemini_3?: #{response.gemini_3?}"
    puts "thought_signatures: #{response.thought_signatures.length}件"
    puts "has_thought_signature?: #{response.has_thought_signature?}"
  end

  puts "\n" + "=" * 60
  puts "デモ完了"
  puts "=" * 60
rescue StandardError => e
  puts "\nエラーが発生しました: #{e.message}"
  puts e.backtrace.first(5).join("\n") if ENV["DEBUG"]
end
