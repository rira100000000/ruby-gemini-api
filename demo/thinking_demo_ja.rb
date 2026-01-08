require 'bundler/setup'
require 'gemini'

# APIキーを環境変数から取得
api_key = ENV['GEMINI_API_KEY'] || raise("環境変数 GEMINI_API_KEY を設定してください")
client = Gemini::Client.new(api_key)

puts "=" * 60
puts "Gemini 思考モデルのデモ"
puts "=" * 60

# 例1: 基本的な思考モード（Gemini 2.5用 - thinkingBudget）
puts "\n【例1】基本的な思考モード（Gemini 2.5）"
puts "-" * 60
begin
  response = client.generate_content(
    "次の問題を解いてください: ある数を2倍してから7を足すと23になります。その数は何ですか?",
    model: "gemini-2.5-flash",
    thinking_config: 8192  # Gemini 2.5用: thinkingBudgetの簡易指定
  )

  if response.has_thoughts?
    puts "\n[思考プロセス]:"
    puts response.thought_text
    puts "\n[最終回答]:"
    puts response.text  # デフォルトで思考を除外
  else
    puts response.text
  end
rescue => e
  puts "エラー: #{e.message}"
  puts "注意: Gemini 2.5以降のモデルが必要です"
end

# 例2: 詳細な設定（Gemini 2.5用 - thinkingBudget詳細指定）
puts "\n\n【例2】詳細な設定（thinkingBudgetを明示指定）"
puts "-" * 60
begin
  response = client.generate_content(
    "フィボナッチ数列の10番目の数を求めてください",
    model: "gemini-2.5-flash",
    thinking_config: {
      thinking_budget: 16384
    }
  )

  if response.has_thoughts?
    puts "\n[思考プロセス]:"
    puts response.thought_text
    puts "\n[最終回答]:"
    puts response.non_thought_text
    puts "\n[Thought Signatures]:"
    puts response.thought_signatures.inspect
  else
    puts response.text
  end
rescue => e
  puts "エラー: #{e.message}"
end

# 例3: Gemini 2.5での思考バジェット指定
puts "\n\n【例3】思考バジェット指定（Gemini 2.5）"
puts "-" * 60
begin
  response = client.generate_content(
    "量子コンピュータの仕組みを簡単に説明してください",
    model: "gemini-2.5-flash",
    thinking_config: 2048  # thinking_budgetの簡易指定
  )

  if response.has_thoughts?
    puts "\n[思考あり]"
    puts "思考: #{response.thought_text}"
    puts "回答: #{response.text}"
  else
    puts response.text
  end
rescue => e
  puts "エラー: #{e.message}"
end

# 例4: Conversationクラスで会話履歴管理（Thought Signaturesの自動保持）
puts "\n\n【例4】会話履歴管理（Thought Signaturesの自動保持）"
puts "-" * 60
begin
  # Conversationクラスでシグネチャを自動管理
  conversation = Gemini::Conversation.new(
    client: client,
    model: "gemini-2.5-flash",
    thinking_config: 8192  # Gemini 2.5用: thinkingBudget
  )

  # 最初のメッセージ
  puts "\n[質問1] 123 × 456 はいくつですか？"
  response1 = conversation.send_message("123 × 456 はいくつですか？")

  if response1.has_thoughts?
    puts "[思考] #{response1.thought_text[0..100]}..."
  end
  puts "[回答] #{response1.text}"

  # 2回目のメッセージ（Thought Signaturesが自動的に保持される）
  puts "\n[質問2] その結果を7で割ると？"
  response2 = conversation.send_message("その結果を7で割ると？")

  if response2.has_thoughts?
    puts "[思考] #{response2.thought_text[0..100]}..."
  end
  puts "[回答] #{response2.text}"

  # 会話履歴を確認
  puts "\n[会話履歴の件数]: #{conversation.get_history.size}件"
rescue => e
  puts "エラー: #{e.message}"
end

# 例5: ストリーミングで思考を含むレスポンスを受信
puts "\n\n【例5】ストリーミング（思考を含む）"
puts "-" * 60
begin
  puts "1から5まで数えて、なぜそうするのか説明してください:"

  client.generate_content(
    "1から5まで数えて、なぜそうするのか説明してください",
    model: "gemini-2.5-flash",
    thinking_config: 8192  # Gemini 2.5用
  ) do |chunk_text, chunk|
    # 思考部分かどうかをチェック
    part = chunk.dig("candidates", 0, "content", "parts", 0)
    if part && part["thought"] == true
      print "[思考] "
    end
    print chunk_text
  end
  puts "\n"
rescue => e
  puts "エラー: #{e.message}"
end

# 例6: 後方互換性（thinking_configなしでも動作）
puts "\n\n【例6】後方互換性（thinking_configなし）"
puts "-" * 60
begin
  # thinking_configを指定しない通常のリクエスト
  response = client.generate_content(
    "こんにちは",
    model: "gemini-2.5-flash"
    # thinking_config なし
  )

  puts "has_thoughts?: #{response.has_thoughts?}"
  puts "text: #{response.text}"
rescue => e
  puts "エラー: #{e.message}"
end

# 例7: full_contentで思考部分を視覚的に識別
puts "\n\n【例7】full_contentメソッド（思考部分の可視化）"
puts "-" * 60
begin
  response = client.generate_content(
    "2の10乗は？",
    model: "gemini-2.5-flash",
    thinking_config: 8192
  )

  puts "\nfull_content (思考部分に[THOUGHT]プレフィックス):"
  puts response.full_content
rescue => e
  puts "エラー: #{e.message}"
end

puts "\n" + "=" * 60
puts "デモ完了"
puts "=" * 60
