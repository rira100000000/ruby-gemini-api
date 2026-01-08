require 'bundler/setup'
require 'gemini'

# APIキーを環境変数から取得
api_key = ENV['GEMINI_API_KEY'] || raise("環境変数 GEMINI_API_KEY を設定してください")
client = Gemini::Client.new(api_key)

puts "=" * 60
puts "Gemini 2.5 思考モデル + Function Calling デモ"
puts "=" * 60
puts ""
puts "【このデモについて】"
puts "  Gemini 2.5の思考モードとFunction Callingの組み合わせを検証します。"
puts "  重要: Gemini 2.5では、関数宣言を含むリクエストでのみThought Signaturesが返されます。"
puts ""
puts "【検証するポイント】"
puts "  1. Function Callingなしの場合、Thought Signaturesが返されないこと"
puts "  2. Function Callingありの場合、Thought Signaturesが正しく取得できること"
puts "  3. Conversationクラスでシグネチャが自動的に保持されること"
puts "  4. 複数の関数呼び出しでも正しく動作すること"
puts "=" * 60

# 関数定義（計算機能）
calculator_function = {
  function_declarations: [
    {
      name: "calculate",
      description: "四則演算を実行します。複雑な計算は複数回に分けて呼び出してください。",
      parameters: {
        type: "object",
        properties: {
          operation: {
            type: "string",
            description: "演算の種類",
            enum: ["add", "subtract", "multiply", "divide", "power", "sqrt"]
          },
          a: {
            type: "number",
            description: "第1オペランド"
          },
          b: {
            type: "number",
            description: "第2オペランド（sqrtの場合は不要）"
          }
        },
        required: ["operation", "a"]
      }
    },
    {
      name: "compare_numbers",
      description: "2つの数値を比較します",
      parameters: {
        type: "object",
        properties: {
          a: {
            type: "number",
            description: "比較する第1の数"
          },
          b: {
            type: "number",
            description: "比較する第2の数"
          }
        },
        required: ["a", "b"]
      }
    }
  ]
}

# 例1: Function Callingなしのリクエスト（比較用）
puts "\n【例1】Function Callingなし（比較用）"
puts "-" * 60
puts "【デモの目的】"
puts "  思考モードを有効にしても、関数宣言がない場合は"
puts "  Thought Signaturesが返されないことを確認します。"
puts ""
puts "【期待される結果】"
puts "  - has_thoughts?はtrueまたはfalse（思考textはある可能性）"
puts "  - thought_signaturesは空配列（Gemini 2.5の制約）"
puts "  - 通常のテキスト回答が得られる"
puts ""
puts "【実行中】関数宣言なしでリクエストしています..."
puts "-" * 60
begin
  response = client.generate_content(
    "次の3つの投資オプションがあります：A) 初期投資100万円で年利5%、B) 初期投資80万円で年利7%、C) 初期投資120万円で年利4%。10年後に最も利益が大きいのはどれですか？",
    model: "gemini-2.5-flash",
    thinking_config: 8192
  )

  puts "has_thoughts?: #{response.has_thoughts?}"
  puts "thought_signatures count: #{response.thought_signatures.size}"
  puts "text: #{response.text}"

  puts "\n【結果の解説】"
  if response.thought_signatures.empty?
    puts "  ✓ 予想通り、Thought Signaturesは空です"
    puts "  → Gemini 2.5では関数宣言なしの場合、シグネチャは返されません"
  else
    puts "  ! 予想外: Thought Signaturesが含まれています（#{response.thought_signatures.size}件）"
  end
  if response.has_thoughts?
    puts "  ✓ 思考テキスト自体は含まれています"
  end
rescue => e
  puts "エラー: #{e.message}"
end

# 例2: Function Callingありのリクエスト（Thought Signaturesが返されるはず）
puts "\n\n【例2】Function Callingあり（Thought Signaturesを取得）"
puts "-" * 60
puts "【デモの目的】"
puts "  関数宣言を含むリクエストで、Thought Signaturesが正しく取得できることを確認します。"
puts "  これがGemini 2.5でThought Signaturesを取得する唯一の方法です。"
puts "  複雑な質問（比較・判断が必要）により思考プロセスを引き出します。"
puts ""
puts "【期待される結果】"
puts "  - has_thought_signatures?がtrueを返す（重要）"
puts "  - thought_signaturesに1つ以上のシグネチャが含まれる"
puts "  - 関数呼び出しが計画される（加算、乗算、除算など）"
puts "  - 注意: has_thoughts?はfalseの場合が多い（Gemini 2.5の仕様）"
puts "  - Thought Signaturesが取得できれば、思考プロセスは機能している"
puts ""
puts "【実行中】複雑な質問で関数呼び出しをリクエストしています..."
puts "-" * 60
begin
  response = client.generate_content(
    "3つの数値、123、456、789があります。これらの合計を計算し、その結果を2倍にし、さらに100で割った値を求めてください。最終的な値を教えてください。",
    model: "gemini-2.5-flash",
    thinking_config: 8192,
    tools: [calculator_function]
  )

  puts "has_thoughts?: #{response.has_thoughts?}"
  puts "has_thought_signatures?: #{response.has_thought_signatures?}"
  puts "thought_signatures count: #{response.thought_signatures.size}"

  if response.has_thoughts?
    puts "\n[思考プロセス（先頭200文字）]:"
    puts response.thought_text[0..200] + "..."

    puts "\n[Thought Signatures]:"
    response.thought_signatures.each_with_index do |sig, i|
      puts "  Signature #{i + 1}:"
      puts "    Text: #{sig[:text][0..100]}..."
      puts "    Signature: #{sig[:signature][0..50]}..."
    end
  end

  puts "\n[関数呼び出し]:"
  if response.function_calls.any?
    response.function_calls.each do |fc|
      puts "  Function: #{fc['name']}"
      puts "  Args: #{fc['args'].inspect}"
    end
  else
    puts "  なし"
  end

  puts "\n[テキスト応答]:"
  puts response.text if response.text && !response.text.empty?

  puts "\n[Full Content（思考部分に[THOUGHT]プレフィックス）]:"
  puts response.full_content[0..300] + "..."

  puts "\n【結果の解説】"
  if response.has_thought_signatures?
    puts "  ✓ Thought Signaturesが正常に取得できました（#{response.thought_signatures.size}件）"
    puts "  ✓ これらのシグネチャは会話履歴に保存され、文脈維持に使用されます"
  else
    puts "  ✗ Thought Signaturesが取得できませんでした"
  end
  if response.function_calls.any?
    puts "  ✓ 関数呼び出しが正しく行われました（#{response.function_calls.size}件）"
  end
rescue => e
  puts "エラー: #{e.message}"
  puts e.backtrace.first(5)
end

# 例3: Conversationクラスで関数呼び出しを含む会話（Thought Signaturesの自動保持）
puts "\n\n【例3】Conversationクラス + Function Calling（シグネチャ自動保持）"
puts "-" * 60
puts "【デモの目的】"
puts "  Conversationクラスで関数呼び出しを使用した場合、"
puts "  Thought Signaturesが会話履歴に自動的に保存されることを確認します。"
puts ""
puts "【期待される結果】"
puts "  - レスポンスにThought Signaturesが含まれる"
puts "  - 会話履歴にシグネチャが保持される"
puts "  - 次の質問でこのシグネチャが利用可能になる"
puts ""
puts "【実行中】会話履歴を管理しながら質問しています..."
puts "-" * 60
begin
  conversation = Gemini::Conversation.new(
    client: client,
    model: "gemini-2.5-flash",
    thinking_config: 8192
  )

  # 最初のメッセージ（関数宣言を含む）
  puts "\n[質問1] 複利計算：100万円を年利5%で10年運用した場合の最終金額は？"
  response1 = conversation.send_message(
    "100万円を年利5%で10年間複利運用した場合、最終的にいくらになりますか？計算過程も教えてください。",
    tools: [calculator_function]
  )

  puts "has_thoughts?: #{response1.has_thoughts?}"
  puts "has_thought_signatures?: #{response1.has_thought_signatures?}"
  puts "thought_signatures: #{response1.thought_signatures.size}件"

  if response1.function_calls.any?
    puts "関数呼び出し:"
    response1.function_calls.each do |fc|
      puts "  - #{fc['name']}: #{fc['args'].inspect}"
    end
  end

  # ここで通常は関数を実行して結果を返すが、デモなのでスキップ
  # 実際のアプリでは：
  # 1. response1.function_calls を確認
  # 2. 各関数を実行
  # 3. 結果を conversation.send_message で返す

  puts "\n[会話履歴の件数]: #{conversation.get_history.size}件"

  # 履歴にThought Signaturesが含まれているか確認
  if conversation.get_history.size > 1
    model_response = conversation.get_history[1]
    puts "[履歴にシグネチャが保持されているか]:"
    if model_response && model_response["parts"]
      has_sig = model_response["parts"].any? { |p| p.key?("thoughtSignature") }
      puts "  #{has_sig ? 'はい - シグネチャが保持されています' : 'いいえ'}"
    end
  end

  puts "\n【結果の解説】"
  if response1.has_thought_signatures?
    puts "  ✓ Thought Signaturesが正常に取得できました"
  end
  if conversation.get_history.size > 1
    model_response = conversation.get_history[1]
    if model_response && model_response["parts"]
      has_sig = model_response["parts"].any? { |p| p.key?("thoughtSignature") }
      if has_sig
        puts "  ✓ 会話履歴にシグネチャが自動的に保持されています"
        puts "  → Conversationクラスが自動的にシグネチャを管理しています"
        puts "  → これにより、複数ターンの会話で文脈が維持されます"
      end
    end
  end
rescue => e
  puts "エラー: #{e.message}"
  puts e.backtrace.first(5)
end

# 例4: 複数の関数宣言と複雑な質問
puts "\n\n【例4】複数関数 + 複雑な質問"
puts "-" * 60
puts "【デモの目的】"
puts "  複数の関数呼び出しが必要な複雑な質問で、"
puts "  思考プロセスが適切に機能することを確認します。"
puts ""
puts "【期待される結果】"
puts "  - より大きなthinking_budget (16384) により詳細な思考が得られる"
puts "  - 複数の計算が順序立てて実行される"
puts "  - thought_partsとnon_thought_partsが適切に分離される"
puts "  - 計算結果の比較や判定が行われる"
puts ""
puts "【実行中】複雑な質問を処理しています..."
puts "-" * 60
begin
  response = client.generate_content(
    "次の問題を解いてください：(15 × 23) + (89 × 12) - (45 × 7) の計算結果を求め、その値が1000より大きいか小さいか判定してください。",
    model: "gemini-2.5-flash",
    thinking_config: 16384,  # より大きなbudgetで思考を促す
    tools: [calculator_function]
  )

  puts "has_thoughts?: #{response.has_thoughts?}"

  if response.has_thoughts?
    puts "\n[思考の詳細]:"
    puts "  thought_parts count: #{response.thought_parts.size}"
    puts "  non_thought_parts count: #{response.non_thought_parts.size}"
    puts "  thought_signatures count: #{response.thought_signatures.size}"

    puts "\n[思考テキスト（先頭200文字）]:"
    puts response.thought_text[0..200] + "..."
  end

  puts "\n[関数呼び出し]:"
  if response.function_calls.any?
    response.function_calls.each_with_index do |fc, i|
      puts "  #{i + 1}. #{fc['name']}"
      puts "     Args: #{fc['args'].inspect}"
    end
  else
    puts "  なし"
  end

  puts "\n【結果の解説】"
  if response.has_thoughts?
    puts "  ✓ thinking_budget: 16384 により詳細な思考プロセスが得られました"
    puts "  ✓ thought_partsが#{response.thought_parts.size}個、non_thought_partsが#{response.non_thought_parts.size}個"
  end
  if response.function_calls.any?
    puts "  ✓ #{response.function_calls.size}個の関数呼び出しが計画されました"
    puts "  → モデルは複雑な要求を複数の関数呼び出しに分解しました"
  end
rescue => e
  puts "エラー: #{e.message}"
end

# 例5: parts_with_signatures メソッドのテスト
puts "\n\n【例5】parts_with_signatures メソッドのテスト"
puts "-" * 60
puts "【デモの目的】"
puts "  parts_with_signaturesメソッドが、思考部分を除外しつつ"
puts "  Thought Signaturesを保持する動作を確認します。"
puts ""
puts "【期待される結果】"
puts "  - 元のpartsには思考partsとthoughtSignaturesが含まれる"
puts "  - parts_with_signaturesでは思考partsが除外される"
puts "  - parts_with_signaturesでもthoughtSignaturesは保持される"
puts "  - content_for_historyで会話履歴用のコンテンツが取得できる"
puts ""
puts "【実行中】partsの変換をテストしています..."
puts "-" * 60
begin
  response = client.generate_content(
    "次の計算を段階的に行ってください：√144 を計算し、その結果を5倍し、さらに20を引いた値を求めてください。",
    model: "gemini-2.5-flash",
    thinking_config: 8192,
    tools: [calculator_function]
  )

  if response.has_thoughts?
    puts "\n[元のparts]:"
    response.parts.each_with_index do |part, i|
      puts "  Part #{i + 1}:"
      puts "    Keys: #{part.keys.inspect}"
      puts "    thought: #{part['thought']}" if part.key?('thought')
      puts "    thoughtSignature: #{part['thoughtSignature'] ? '存在' : 'なし'}"
    end

    puts "\n[parts_with_signatures（会話履歴用）]:"
    response.parts_with_signatures.each_with_index do |part, i|
      puts "  Part #{i + 1}:"
      puts "    Keys: #{part.keys.inspect}"
      puts "    thought: #{part['thought']}" if part.key?('thought')
      puts "    thoughtSignature: #{part['thoughtSignature'] ? '存在' : 'なし'}"
    end

    puts "\n[content_for_history]:"
    content = response.content_for_history
    puts "  role: #{content['role']}"
    puts "  parts count: #{content['parts'].size}"

    puts "\n【結果の解説】"
    orig_count = response.parts.size
    preserved_count = response.parts_with_signatures.size
    puts "  ✓ 元のpartsは#{orig_count}個、parts_with_signaturesは#{preserved_count}個"
    if orig_count > preserved_count
      puts "  ✓ 思考parts（thought: true）が除外されました"
    end
    has_sig_in_preserved = response.parts_with_signatures.any? { |p| p.key?('thoughtSignature') }
    if has_sig_in_preserved
      puts "  ✓ thoughtSignatureは保持されています"
      puts "  → 会話履歴に保存する際、思考内容は除外されますがシグネチャは保持されます"
      puts "  → これによりトークン使用量を削減しつつ、文脈の連続性を維持できます"
    end
  else
    puts "思考partsが含まれていません"
  end
rescue => e
  puts "エラー: #{e.message}"
end

puts "\n" + "=" * 60
puts "デモ完了"
puts "=" * 60
puts ""
puts "【総括】"
puts "このデモでは以下を確認しました："
puts "  1. Gemini 2.5では関数宣言なしでThought Signaturesが返されない"
puts "  2. 関数宣言ありでThought Signaturesが正しく取得できる"
puts "  3. Conversationクラスがシグネチャを自動的に管理する"
puts "  4. 複雑な計算問題でも適切に関数呼び出しが計画される"
puts "  5. parts_with_signaturesで思考内容を除外しつつシグネチャを保持できる"
puts ""
puts "【重要なポイント】"
puts "  • Gemini 2.5でThought Signaturesを取得するには関数宣言が必須"
puts "  • Conversationクラスを使うと、シグネチャの管理が自動化される"
puts "  • 会話履歴には思考内容を含めず、シグネチャのみを保存することでトークンを節約"
puts "  • 計算や論理的推論が必要な質問では思考プロセスが発動しやすい"
puts ""
puts "詳細はREADMEの「Function CallingとThought Signatures」セクションを参照してください。"
