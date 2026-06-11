#!/usr/bin/env ruby
# frozen_string_literal: true

# Code Execution（コード実行）デモ
#
# Code Execution を使うと、Gemini が必要に応じて Python コードを生成・実行し、
# 計算やデータ処理を含む回答を作れます。最終回答は response.text でそのまま取り出せて、
# 生成されたコードや実行結果も別々に確認できます。
#
# 使い方:
#   ruby demo/code_execution_demo_ja.rb
#
# 環境変数:
#   GEMINI_API_KEY - Gemini API キー（必須）
#   GEMINI_MODEL   - モデルを変えたい場合に指定（デフォルト: gemini-3.5-flash）

require 'bundler/setup'
require 'gemini'

api_key = ENV['GEMINI_API_KEY'] || raise("GEMINI_API_KEY 環境変数を設定してください")
model = ENV['GEMINI_MODEL'] || "gemini-3.5-flash"

begin
  puts "=" * 60
  puts "Gemini Code Execution デモ"
  puts "Model: #{model}"
  puts "=" * 60
  puts
  puts "このデモでわかること:"
  puts "- generate_content に code_execution: true を足すだけで使える"
  puts "- Gemini が Python を実行して計算を確認できる"
  puts "- 最終回答、生成コード、実行結果をそれぞれ取り出せる"
  puts

  client = Gemini::Client.new(api_key)

  prompt = "最初の50個の素数の合計を計算してください。Pythonコードで結果を確認し、最後に短く説明してください。"

  puts "プロンプト:"
  puts prompt
  puts
  puts "code_execution: true で Gemini にリクエストします..."
  puts

  response = client.generate_content(
    prompt,
    model: model,
    code_execution: true
  )

  unless response.success?
    puts "エラー: #{response.error || 'Unknown error'}"
    exit 1
  end

  puts "最終回答:"
  puts response.text
  puts

  if response.code_execution?
    puts "生成された Python コード:"
    puts "-" * 40
    puts response.executable_code || "（コードは返されませんでした）"
    puts "-" * 40
    puts

    puts "実行ステータス: #{response.code_execution_outcome || 'unknown'}"
    puts

    puts "実行結果:"
    puts "-" * 40
    puts response.code_execution_output || "（実行結果は返されませんでした）"
    puts "-" * 40
  else
    puts "Code Execution の結果は返されませんでした。"
    puts "モデルがコード実行なしで回答した可能性があります。"
  end

  puts
  puts "=" * 60
  puts "デモ完了"
  puts "=" * 60
rescue StandardError => e
  puts "\nエラーが発生しました: #{e.message}"
  puts e.backtrace.first(5).join("\n") if ENV["DEBUG"]
end
