require 'bundler/setup'
require 'gemini'

# APIキーを環境変数から取得
api_key = ENV['GEMINI_API_KEY'] || raise("環境変数 GEMINI_API_KEY を設定してください")
client = Gemini::Client.new(api_key)

puts "=" * 60
puts "Gemini 3 + Function Calling + Thought Signatures テスト"
puts "=" * 60
puts ""
puts "【このテストについて】"
puts "  Gemini 3では、Thought Signaturesの配置ルールがGemini 2.5と異なります："
puts "  • 関数呼び出しあり: 最初の関数呼び出しpartにシグネチャが含まれる"
puts "  • 関数呼び出しなし: 最後のpartにシグネチャが含まれる"
puts ""
puts "【検証する項目】"
puts "  1. 関数呼び出し時にシグネチャが正しい位置に配置されること"
puts "  2. parts_with_signaturesでシグネチャが保持されること"
puts "  3. Conversationクラスで会話履歴にシグネチャが保存されること"
puts "  4. 関数呼び出しなしの場合、最後のpartにシグネチャがあること"
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
    }
  ]
}

# テスト1: Gemini 3 + Function Calling
puts "\n【テスト1】Gemini 3 + Function Calling（シグネチャの場所を確認）"
puts "-" * 60
puts "【テストの目的】"
puts "  Gemini 3で関数呼び出しがある場合、Thought Signatureが"
puts "  最初の関数呼び出しpartに含まれることを確認します。"
puts ""
puts "【期待される結果】"
puts "  - 思考parts（thought: true）が含まれる"
puts "  - 最初の関数呼び出しpartにthoughtSignatureキーが存在する"
puts "  - parts_with_signaturesでも関数呼び出しpartにシグネチャが保持される"
puts ""
puts "【実行中】Gemini 3に関数呼び出しを含むリクエストを送信しています..."
puts "-" * 60
begin
  response = client.generate_content(
    "3つの数値、123、456、789があります。これらの合計を計算し、その結果を2倍にし、さらに100で割った値を求めてください。最終的な値を教えてください。",
    model: "gemini-3-flash-preview",
    thinking_config: { thinking_level: "high", include_thoughts: true },
    tools: [calculator_function]
  )

  puts "\n[基本情報]:"
  puts "has_thoughts?: #{response.has_thoughts?}"
  puts "has_thought_signatures?: #{response.has_thought_signatures?}"
  puts "thought_signatures count: #{response.thought_signatures.size}"

  puts "\n[全Partsの詳細]:"
  response.parts.each_with_index do |part, i|
    puts "  Part #{i + 1}:"
    puts "    Keys: #{part.keys.inspect}"
    puts "    thought: #{part['thought']}" if part.key?('thought')
    puts "    thoughtSignature: #{part['thoughtSignature'] ? '存在（先頭50文字）: ' + part['thoughtSignature'][0..49] + '...' : 'なし'}"
    puts "    functionCall: #{part['functionCall']['name']}" if part.key?('functionCall')
    puts "    text preview: #{part['text'][0..50]}..." if part.key?('text') && part['text']
  end

  puts "\n[parts_with_signatures（会話履歴用）]:"
  response.parts_with_signatures.each_with_index do |part, i|
    puts "  Part #{i + 1}:"
    puts "    Keys: #{part.keys.inspect}"
    puts "    thought: #{part['thought']}" if part.key?('thought')
    puts "    thoughtSignature: #{part['thoughtSignature'] ? '存在' : 'なし'}"
    puts "    functionCall: #{part['functionCall']['name']}" if part.key?('functionCall')
  end

  puts "\n" + "=" * 60
  puts "【検証結果】"
  puts "=" * 60
  # 最初の関数呼び出し部分にシグネチャがあるか確認
  first_fc_part = response.parts.find { |p| p.key?('functionCall') }
  if first_fc_part
    puts "✓ 関数呼び出しpartが見つかりました"
    if first_fc_part.key?('thoughtSignature')
      puts "✓ 最初の関数呼び出し部分にシグネチャが含まれています（Gemini 3の仕様通り）"
      puts "  → Gemini 3では、関数呼び出しがある場合、最初のfunctionCallにシグネチャが付きます"
    else
      puts "✗ 最初の関数呼び出し部分にシグネチャがありません（予期しない動作）"
    end

    # parts_with_signaturesでも保持されているか確認
    fc_in_preserved = response.parts_with_signatures.find { |p| p.key?('functionCall') }
    if fc_in_preserved && fc_in_preserved.key?('thoughtSignature')
      puts "✓ parts_with_signaturesでもシグネチャが保持されています"
      puts "  → 会話履歴に保存する際もシグネチャが正しく維持されます"
    elsif fc_in_preserved
      puts "✗ parts_with_signaturesでシグネチャが失われています（バグの可能性）"
    end
  else
    puts "✗ 関数呼び出しpartが見つかりません"
  end

rescue => e
  puts "エラー: #{e.message}"
  puts e.backtrace.first(5)
end

# テスト2: Gemini 3 + Function Calling + Conversation（会話履歴管理）
puts "\n\n【テスト2】Gemini 3 + Conversation（シグネチャの自動保持）"
puts "-" * 60
puts "【テストの目的】"
puts "  Conversationクラスを使用した場合、関数呼び出しpartに含まれる"
puts "  Thought Signatureが会話履歴に正しく保存されることを確認します。"
puts ""
puts "【期待される結果】"
puts "  - レスポンスにThought Signaturesが含まれる"
puts "  - 会話履歴の関数呼び出しpartにシグネチャが保存される"
puts "  - シグネチャは次の質問で利用可能になる"
puts ""
puts "【実行中】Conversationクラスで質問しています..."
puts "-" * 60
begin
  conversation = Gemini::Conversation.new(
    client: client,
    model: "gemini-3-flash-preview",
    thinking_config: { thinking_level: "high", include_thoughts: true }
  )

  # 最初のメッセージ（関数宣言を含む）
  puts "\n[質問1] 複利計算：100万円を年利5%で10年運用した場合の最終金額は？"
  response1 = conversation.send_message(
    "100万円を年利5%で10年間複利運用した場合、最終的にいくらになりますか？計算過程も教えてください。",
    tools: [calculator_function]
  )

  puts "has_thoughts?: #{response1.has_thoughts?}"
  puts "has_thought_signatures?: #{response1.has_thought_signatures?}"

  if response1.function_calls.any?
    puts "関数呼び出し: #{response1.function_calls.map { |fc| fc['name'] }.join(', ')}"
  end

  puts "\n[会話履歴の確認]:"
  history = conversation.get_history
  puts "  履歴件数: #{history.size}"

  if history.size > 1
    model_response = history[1]  # モデルのレスポンス
    puts "  モデルレスポンスのparts数: #{model_response['parts'].size}"

    # 関数呼び出し部分を探す
    fc_part = model_response['parts'].find { |p| p.key?('functionCall') }
    if fc_part
      puts "  ✓ 履歴に関数呼び出しpartが保存されています"
      if fc_part.key?('thoughtSignature')
        puts "  ✓ 関数呼び出しpartにシグネチャが保持されています"
        puts "    シグネチャ（先頭50文字）: #{fc_part['thoughtSignature'][0..50]}..."
      else
        puts "  ✗ 関数呼び出しpartにシグネチャがありません"
      end
    else
      puts "  ✗ 履歴に関数呼び出しpartが見つかりません"
    end
  end

  puts "\n" + "=" * 60
  puts "【検証結果】"
  puts "=" * 60
  if history.size > 1
    model_response = history[1]
    fc_part = model_response['parts'].find { |p| p.key?('functionCall') }
    if fc_part && fc_part.key?('thoughtSignature')
      puts "✓ Conversationクラスが関数呼び出しpartのシグネチャを正しく保存しました"
      puts "  → 思考内容（thought: true）は除外されています"
      puts "  → シグネチャは保持されており、次のターンで文脈として使用できます"
      puts "  → これによりトークン使用量を削減しつつ、会話の連続性を維持できます"
    else
      puts "✗ シグネチャが正しく保存されていません"
    end
  end

rescue => e
  puts "エラー: #{e.message}"
  puts e.backtrace.first(5)
end

# テスト3: Gemini 3 without function calls（関数呼び出しなし）
puts "\n\n【テスト3】Gemini 3 without Function Calling（関数呼び出しなし）"
puts "-" * 60
puts "【テストの目的】"
puts "  Gemini 3で関数呼び出しがない場合、Thought Signatureが"
puts "  最後のpartに含まれることを確認します。"
puts ""
puts "【期待される結果】"
puts "  - 思考parts（thought: true）が含まれる"
puts "  - 最後のpartにthoughtSignatureキーが存在する"
puts "  - これはGemini 3の仕様（関数呼び出しなしの場合）"
puts ""
puts "【実行中】関数宣言なしでリクエストしています..."
puts "-" * 60
begin
  response = client.generate_content(
    "2の10乗を計算して、その値が1000と2000のどちらに近いか、理由とともに説明してください。",
    model: "gemini-3-flash-preview",
    thinking_config: { thinking_level: "high", include_thoughts: true }
    # tools なし
  )

  puts "\n[基本情報]:"
  puts "has_thoughts?: #{response.has_thoughts?}"
  puts "has_thought_signatures?: #{response.has_thought_signatures?}"

  puts "\n[全Partsの詳細]:"
  response.parts.each_with_index do |part, i|
    puts "  Part #{i + 1}:"
    puts "    Keys: #{part.keys.inspect}"
    puts "    thought: #{part['thought']}" if part.key?('thought')
    puts "    thoughtSignature: #{part['thoughtSignature'] ? '存在（先頭50文字）: ' + part['thoughtSignature'][0..49] + '...' : 'なし'}"
    puts "    text preview: #{part['text'][0..50]}..." if part.key?('text') && part['text']
  end

  puts "\n" + "=" * 60
  puts "【検証結果】"
  puts "=" * 60
  last_part = response.parts.last
  if last_part && last_part.key?('thoughtSignature')
    puts "✓ 最後のpartにシグネチャが含まれています（Gemini 3の仕様通り）"
    puts "  → 関数呼び出しがない場合、最後のpartにシグネチャが配置されます"
    puts "  → これはGemini 2.5とは異なる配置ルールです"
  else
    puts "✗ 最後のpartにシグネチャがありません（予期しない動作）"
  end

rescue => e
  puts "エラー: #{e.message}"
  puts e.backtrace.first(5)
end

puts "\n" + "=" * 60
puts "テスト完了"
puts "=" * 60
puts ""
puts "【総括】"
puts "このテストでは以下を検証しました："
puts "  1. 関数呼び出しありの場合、最初のfunctionCall partにシグネチャが含まれる"
puts "  2. parts_with_signaturesでシグネチャが正しく保持される"
puts "  3. Conversationクラスで会話履歴にシグネチャが保存される"
puts "  4. 関数呼び出しなしの場合、最後のpartにシグネチャが含まれる"
puts ""
puts "【Gemini 3のThought Signatureの特徴】"
puts "  • Gemini 2.5と異なり、関数宣言なしでもシグネチャが返される"
puts "  • 関数呼び出しありの場合は最初のfunctionCall partにシグネチャが付く"
puts "  • 関数呼び出しなしの場合は最後のpartにシグネチャが付く"
puts "  • このライブラリは両方のケースを自動的に処理します"
puts ""
puts "詳細はREADMEの「Gemini 3の思考モデル」セクションを参照してください。"
