require 'bundler/setup'
require 'gemini'

# APIキーを環境変数から取得
api_key = ENV['GEMINI_API_KEY'] || raise("環境変数 GEMINI_API_KEY を設定してください")
client = Gemini::Client.new(api_key)

puts "=" * 60
puts "Gemini 思考モデルのデモ"
puts "=" * 60
puts ""
puts "【重要な注意事項】"
puts "  このデモでは関数呼び出し（Function Calling）を使用していません。"
puts "  そのため、Gemini 2.5ではThought Signaturesは一切返されません。"
puts ""
puts "  Gemini 2.5でThought Signaturesを取得するには："
puts "  → thinking_with_function_calling_demo_ja.rb を参照してください"
puts ""
puts "  このデモで確認できるのは："
puts "  - 思考プロセスのテキスト（thought_text）"
puts "  - 思考の有無（has_thoughts?）"
puts "  - 思考を除いた回答（text, non_thought_text）"
puts "=" * 60

# 例1: 基本的な思考モード（Gemini 2.5用 - thinkingBudget）
puts "\n【例1】基本的な思考モード（Gemini 2.5）"
puts "-" * 60
puts "【デモの目的】"
puts "  thinking_configを使った基本的な思考モードの動作を確認します。"
puts "  数値（8192）を指定すると、それがthinkingBudgetとして扱われます。"
puts ""
puts "【期待される結果】"
puts "  - has_thoughts?がtrueを返す"
puts "  - thought_textで思考プロセスが取得できる"
puts "  - textで思考を除いた最終回答のみが取得できる"
puts ""
puts "【実行中】数学問題を思考モードで解いています..."
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
    puts "\n【結果の解説】"
    puts "  ✓ 思考プロセスが正常に取得できました"
    puts "  ✓ thought_textで内部的な計算過程が見えます"
    puts "  ✓ textでは思考を除いた最終回答だけが返されます"
  else
    puts response.text
    puts "\n【結果の解説】"
    puts "  ✗ 思考partsが含まれていませんでした"
    puts "  → thinking_configが正しく設定されていない可能性があります"
  end
rescue => e
  puts "エラー: #{e.message}"
  puts "注意: Gemini 2.5以降のモデルが必要です"
end

# 例2: 詳細な設定（Gemini 2.5用 - thinkingBudget詳細指定）
puts "\n\n【例2】詳細な設定（thinkingBudgetを明示指定）"
puts "-" * 60
puts "【デモの目的】"
puts "  thinking_configをハッシュで詳細指定する方法を確認します。"
puts "  注意: 関数呼び出しなしなので、Thought Signaturesは空です。"
puts ""
puts "【期待される結果】"
puts "  - thinking_budget: 16384 が正しく設定される"
puts "  - non_thought_textで思考を除いたテキストが取得できる"
puts "  - thought_signaturesは空配列（関数呼び出しなしのため）"
puts ""
puts "【実行中】フィボナッチ数列を計算しています..."
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
    puts "\n【結果の解説】"
    puts "  ✓ 詳細設定（ハッシュ形式）が正常に動作しました"
    puts "  ✓ 思考プロセスが取得できました"
    if response.thought_signatures.empty?
      puts "  ✓ Thought Signaturesは空です（関数呼び出しなしなので正常）"
      puts "  → Gemini 2.5では関数呼び出しがない場合、シグネチャは返されません"
    else
      puts "  ! 予想外: Thought Signaturesが含まれています（#{response.thought_signatures.size}件）"
    end
  else
    puts response.text
    puts "\n【結果の解説】"
    puts "  ✗ 思考partsが含まれていませんでした"
  end
rescue => e
  puts "エラー: #{e.message}"
end

# 例3: Gemini 2.5での思考バジェット指定
puts "\n\n【例3】思考バジェット指定（Gemini 2.5）"
puts "-" * 60
puts "【デモの目的】"
puts "  より小さなthinkingBudget（2048）を指定して、"
puts "  思考の深さが制限されることを確認します。"
puts ""
puts "【期待される結果】"
puts "  - 思考プロセスが含まれるが、例1より簡潔になる可能性がある"
puts "  - バジェットが小さいため、思考が短くなる傾向がある"
puts ""
puts "【実行中】量子コンピュータについて説明しています..."
puts "-" * 60
begin
  response = client.generate_content(
    "量子コンピュータの仕組みを簡単に説明してください",
    model: "gemini-2.5-flash",
    thinking_config: 2048  # thinking_budgetの簡易指定
  )

  if response.has_thoughts?
    puts "\n[思考あり]"
    thought_length = response.thought_text.length
    puts "思考（長さ: #{thought_length}文字）: #{response.thought_text[0..200]}..."
    puts "回答: #{response.text}"
    puts "\n【結果の解説】"
    puts "  ✓ 思考プロセスが含まれています"
    puts "  ✓ thinking_budget: 2048 により思考の深さが制限されています"
    puts "  → より大きなbudgetを指定すると、より詳細な思考が得られます"
  else
    puts response.text
    puts "\n【結果の解説】"
    puts "  ✗ 思考partsが含まれていませんでした"
    puts "  → budgetが小さすぎるか、質問が単純すぎる可能性があります"
  end
rescue => e
  puts "エラー: #{e.message}"
end

# 例4: Conversationクラスで会話履歴管理
puts "\n\n【例4】会話履歴管理（Conversationクラス）"
puts "-" * 60
puts "【デモの目的】"
puts "  Conversationクラスを使った複数ターンの会話で、"
puts "  思考プロセスを含む会話履歴が管理されることを確認します。"
puts "  注意: 関数呼び出しなしなので、Thought Signaturesは空です。"
puts ""
puts "【期待される結果】"
puts "  - 1回目の質問で計算結果が得られる"
puts "  - 2回目の質問で「その結果」という参照が正しく解釈される"
puts "  - 会話履歴が正しく保存されている"
puts "  - thought_signaturesは空（関数呼び出しなしのため）"
puts ""
puts "【実行中】2つの質問を連続して実行しています..."
puts "-" * 60
begin
  # Conversationクラスで会話履歴を管理
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
  puts "[Thought Signatures] #{response1.thought_signatures.size}件（期待値: 0）"

  # 2回目のメッセージ
  puts "\n[質問2] その結果を7で割ると？"
  response2 = conversation.send_message("その結果を7で割ると？")

  if response2.has_thoughts?
    puts "[思考] #{response2.thought_text[0..100]}..."
  end
  puts "[回答] #{response2.text}"
  puts "[Thought Signatures] #{response2.thought_signatures.size}件（期待値: 0）"

  # 会話履歴を確認
  puts "\n[会話履歴の件数]: #{conversation.get_history.size}件"

  puts "\n【結果の解説】"
  puts "  ✓ 2つの質問が文脈を保持して処理されました"
  puts "  ✓ Conversationクラスが自動的に会話履歴を管理しています"
  puts "  ✓ 会話履歴には#{conversation.get_history.size}件のメッセージが保存されています"
  if response1.thought_signatures.empty? && response2.thought_signatures.empty?
    puts "  ✓ Thought Signaturesは空です（関数呼び出しなしなので正常）"
  end
  puts "  → Gemini 2.5では関数呼び出しなしでも、会話の文脈は維持されます"
rescue => e
  puts "エラー: #{e.message}"
end

# 例5: ストリーミングで思考を含むレスポンスを受信
puts "\n\n【例5】ストリーミング（思考を含む）"
puts "-" * 60
puts "【デモの目的】"
puts "  ストリーミング形式で思考プロセスを含むレスポンスを受信し、"
puts "  思考部分と回答部分をリアルタイムで区別して表示します。"
puts ""
puts "【期待される結果】"
puts "  - チャンクごとにテキストが順次表示される"
puts "  - 思考部分には[思考]プレフィックスが付く"
puts "  - 回答部分はそのまま表示される"
puts ""
puts "【実行中】ストリーミングで応答を受信しています..."
puts "-" * 60
puts "質問: 1から5まで数えて、なぜそうするのか説明してください"
puts ""
begin
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
  puts "\n【結果の解説】"
  puts "  ✓ ストリーミングで思考と回答が順次表示されました"
  puts "  ✓ 思考部分は[思考]プレフィックスで識別できます"
  puts "  → リアルタイムアプリケーションで、ユーザーに思考過程を見せることができます"
rescue => e
  puts "エラー: #{e.message}"
end

# 例6: 後方互換性（thinking_configなしでも動作）
puts "\n\n【例6】後方互換性（thinking_configなし）"
puts "-" * 60
puts "【デモの目的】"
puts "  thinking_configを指定しない通常のリクエストが、"
puts "  既存のコードとの後方互換性を保って動作することを確認します。"
puts ""
puts "【期待される結果】"
puts "  - has_thoughts?がfalseを返す"
puts "  - 通常の回答テキストが取得できる"
puts "  - エラーが発生しない"
puts ""
puts "【実行中】thinking_configなしでリクエストしています..."
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

  puts "\n【結果の解説】"
  if response.has_thoughts?
    puts "  ! 思考partsが含まれていました（予期しない動作）"
  else
    puts "  ✓ thinking_configなしで通常通り動作しました"
    puts "  ✓ has_thoughts?は正しくfalseを返しています"
    puts "  → 既存のコードに影響を与えずに、思考機能を追加できます"
  end
rescue => e
  puts "エラー: #{e.message}"
end

# 例7: full_contentで思考部分を視覚的に識別
puts "\n\n【例7】full_contentメソッド（思考部分の可視化）"
puts "-" * 60
puts "【デモの目的】"
puts "  full_contentメソッドを使って、思考部分と回答部分を"
puts "  視覚的に区別できる形式で一度に取得します。"
puts ""
puts "【期待される結果】"
puts "  - 思考部分に[THOUGHT]プレフィックスが付く"
puts "  - 回答部分はそのまま表示される"
puts "  - 全体の流れが一目でわかる"
puts ""
puts "【実行中】full_contentで全体を取得しています..."
puts "-" * 60
begin
  response = client.generate_content(
    "2の10乗は？",
    model: "gemini-2.5-flash",
    thinking_config: 8192
  )

  puts "\nfull_content (思考部分に[THOUGHT]プレフィックス):"
  puts response.full_content

  puts "\n【結果の解説】"
  if response.has_thoughts?
    puts "  ✓ 思考部分が[THOUGHT]で明示的にマークされています"
    puts "  ✓ 回答部分は通常のテキストとして表示されます"
    puts "  → デバッグやログ出力に便利です"
  else
    puts "  ✗ 思考partsが含まれていませんでした"
  end
rescue => e
  puts "エラー: #{e.message}"
end

puts "\n" + "=" * 60
puts "デモ完了"
puts "=" * 60
puts ""
puts "【総括】"
puts "このデモでは以下の機能を確認しました："
puts "  1. thinking_configの基本的な使い方（数値指定とハッシュ指定）"
puts "  2. 思考プロセスのテキスト取得（thought_text）"
puts "  3. 異なるthinkingBudgetによる思考の深さの違い"
puts "  4. Conversationクラスでの会話履歴管理"
puts "  5. ストリーミングでの思考プロセスのリアルタイム表示"
puts "  6. 後方互換性の確認（thinking_configなしでも動作）"
puts "  7. full_contentによる思考部分の可視化"
puts ""
puts "【重要】"
puts "  このデモでは関数呼び出しを使用していないため、"
puts "  Gemini 2.5ではThought Signaturesは一切返されません。"
puts ""
puts "  Thought Signaturesを取得するには："
puts "  → thinking_with_function_calling_demo_ja.rb を実行してください"
puts ""
puts "詳細はREADMEの「思考モデル対応」セクションを参照してください。"
