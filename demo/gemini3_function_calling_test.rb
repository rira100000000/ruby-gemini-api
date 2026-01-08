require 'bundler/setup'
require 'gemini'

# APIキーを環境変数から取得
api_key = ENV['GEMINI_API_KEY'] || raise("環境変数 GEMINI_API_KEY を設定してください")
client = Gemini::Client.new(api_key)

puts "=" * 60
puts "Gemini 3 + Function Calling + Thought Signatures テスト"
puts "=" * 60
puts "目的: 関数呼び出し部分にシグネチャが正しく保持されるか確認"
puts "=" * 60

# 関数定義（天気を取得する関数）
weather_function = {
  function_declarations: [
    {
      name: "get_weather",
      description: "指定された場所の現在の天気情報を取得します",
      parameters: {
        type: "object",
        properties: {
          location: {
            type: "string",
            description: "都市名（例：東京、大阪、福岡）"
          },
          unit: {
            type: "string",
            description: "温度の単位",
            enum: ["celsius", "fahrenheit"]
          }
        },
        required: ["location"]
      }
    }
  ]
}

# テスト1: Gemini 3 + Function Calling
puts "\n【テスト1】Gemini 3 + Function Calling（シグネチャの場所を確認）"
puts "-" * 60
begin
  response = client.generate_content(
    "東京の天気はどうですか？",
    model: "gemini-3-flash-preview",
    thinking_config: { thinking_level: "high", include_thoughts: true },
    tools: [weather_function]
  )

  puts "has_thoughts?: #{response.has_thoughts?}"
  puts "has_thought_signatures?: #{response.has_thought_signatures?}"
  puts "thought_signatures count: #{response.thought_signatures.size}"

  puts "\n[全Partsの詳細]:"
  response.parts.each_with_index do |part, i|
    puts "  Part #{i + 1}:"
    puts "    Keys: #{part.keys.inspect}"
    puts "    thought: #{part['thought']}" if part.key?('thought')
    puts "    thoughtSignature: #{part['thoughtSignature'] ? '存在' : 'なし'}"
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

  puts "\n[検証結果]:"
  # 最初の関数呼び出し部分にシグネチャがあるか確認
  first_fc_part = response.parts.find { |p| p.key?('functionCall') }
  if first_fc_part
    puts "  ✓ 関数呼び出しpartが見つかりました"
    if first_fc_part.key?('thoughtSignature')
      puts "  ✓ 最初の関数呼び出し部分にシグネチャが含まれています（Gemini 3の仕様通り）"
    else
      puts "  ✗ 最初の関数呼び出し部分にシグネチャがありません"
    end

    # parts_with_signaturesでも保持されているか確認
    fc_in_preserved = response.parts_with_signatures.find { |p| p.key?('functionCall') }
    if fc_in_preserved && fc_in_preserved.key?('thoughtSignature')
      puts "  ✓ parts_with_signaturesでもシグネチャが保持されています"
    elsif fc_in_preserved
      puts "  ✗ parts_with_signaturesでシグネチャが失われています"
    end
  else
    puts "  ✗ 関数呼び出しpartが見つかりません"
  end

rescue => e
  puts "エラー: #{e.message}"
  puts e.backtrace.first(5)
end

# テスト2: Gemini 3 + Function Calling + Conversation（会話履歴管理）
puts "\n\n【テスト2】Gemini 3 + Conversation（シグネチャの自動保持）"
puts "-" * 60
begin
  conversation = Gemini::Conversation.new(
    client: client,
    model: "gemini-3-flash-preview",
    thinking_config: { thinking_level: "high", include_thoughts: true }
  )

  # 最初のメッセージ（関数宣言を含む）
  puts "\n[質問1] 東京の天気を教えて"
  response1 = conversation.send_message(
    "東京の天気を教えてください",
    tools: [weather_function]
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

rescue => e
  puts "エラー: #{e.message}"
  puts e.backtrace.first(5)
end

# テスト3: Gemini 3 without function calls（関数呼び出しなし）
puts "\n\n【テスト3】Gemini 3 without Function Calling（関数呼び出しなし）"
puts "-" * 60
puts "期待: 最後のpartにシグネチャが含まれる"
begin
  response = client.generate_content(
    "2の10乗はいくつですか？",
    model: "gemini-3-flash-preview",
    thinking_config: { thinking_level: "high", include_thoughts: true }
    # tools なし
  )

  puts "has_thoughts?: #{response.has_thoughts?}"
  puts "has_thought_signatures?: #{response.has_thought_signatures?}"

  puts "\n[全Partsの詳細]:"
  response.parts.each_with_index do |part, i|
    puts "  Part #{i + 1}:"
    puts "    Keys: #{part.keys.inspect}"
    puts "    thought: #{part['thought']}" if part.key?('thought')
    puts "    thoughtSignature: #{part['thoughtSignature'] ? '存在' : 'なし'}"
    puts "    text preview: #{part['text'][0..50]}..." if part.key?('text') && part['text']
  end

  puts "\n[検証結果]:"
  last_part = response.parts.last
  if last_part && last_part.key?('thoughtSignature')
    puts "  ✓ 最後のpartにシグネチャが含まれています（Gemini 3の仕様通り）"
  else
    puts "  ✗ 最後のpartにシグネチャがありません"
  end

rescue => e
  puts "エラー: #{e.message}"
  puts e.backtrace.first(5)
end

puts "\n" + "=" * 60
puts "テスト完了"
puts "=" * 60
