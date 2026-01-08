require 'bundler/setup'
require 'gemini'

# APIキーを環境変数から取得
api_key = ENV['GEMINI_API_KEY'] || raise("環境変数 GEMINI_API_KEY を設定してください")
client = Gemini::Client.new(api_key)

puts "=" * 60
puts "Gemini 2.5 思考モデル + Function Calling デモ"
puts "=" * 60
puts "注意: Gemini 2.5では、関数宣言を含むリクエストでのみThought Signaturesが返されます"
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
    },
    {
      name: "get_forecast",
      description: "指定された場所の天気予報を取得します",
      parameters: {
        type: "object",
        properties: {
          location: {
            type: "string",
            description: "都市名"
          },
          days: {
            type: "integer",
            description: "予報日数（1-7日）"
          }
        },
        required: ["location", "days"]
      }
    }
  ]
}

# 例1: Function Callingなしのリクエスト（比較用）
puts "\n【例1】Function Callingなし（比較用）"
puts "-" * 60
begin
  response = client.generate_content(
    "東京の天気はどうですか？",
    model: "gemini-2.5-flash",
    thinking_config: 8192
  )

  puts "has_thoughts?: #{response.has_thoughts?}"
  puts "thought_signatures: #{response.thought_signatures.inspect}"
  puts "text: #{response.text}"
rescue => e
  puts "エラー: #{e.message}"
end

# 例2: Function Callingありのリクエスト（Thought Signaturesが返されるはず）
puts "\n\n【例2】Function Callingあり（Thought Signaturesを取得）"
puts "-" * 60
begin
  response = client.generate_content(
    "東京の天気はどうですか？",
    model: "gemini-2.5-flash",
    thinking_config: 8192,
    tools: [weather_function]
  )

  puts "has_thoughts?: #{response.has_thoughts?}"
  puts "has_thought_signatures?: #{response.has_thought_signatures?}"
  puts "thought_signatures count: #{response.thought_signatures.size}"

  if response.has_thoughts?
    puts "\n[思考プロセス]:"
    puts response.thought_text

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
  puts response.full_content
rescue => e
  puts "エラー: #{e.message}"
  puts e.backtrace.first(5)
end

# 例3: Conversationクラスで関数呼び出しを含む会話（Thought Signaturesの自動保持）
puts "\n\n【例3】Conversationクラス + Function Calling（シグネチャ自動保持）"
puts "-" * 60
begin
  conversation = Gemini::Conversation.new(
    client: client,
    model: "gemini-2.5-flash",
    thinking_config: 8192
  )

  # 最初のメッセージ（関数宣言を含む）
  puts "\n[質問1] 東京と大阪の天気を教えて"
  response1 = conversation.send_message(
    "東京と大阪の天気を教えてください",
    tools: [weather_function]
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
rescue => e
  puts "エラー: #{e.message}"
  puts e.backtrace.first(5)
end

# 例4: 複数の関数宣言と複雑な質問
puts "\n\n【例4】複数関数 + 複雑な質問"
puts "-" * 60
begin
  response = client.generate_content(
    "今日の東京の天気を教えて。それから明日から3日間の予報も知りたい。",
    model: "gemini-2.5-flash",
    thinking_config: 16384,  # より大きなbudgetで思考を促す
    tools: [weather_function]
  )

  puts "has_thoughts?: #{response.has_thoughts?}"

  if response.has_thoughts?
    puts "\n[思考の詳細]:"
    puts "  thought_parts count: #{response.thought_parts.size}"
    puts "  non_thought_parts count: #{response.non_thought_parts.size}"
    puts "  thought_signatures count: #{response.thought_signatures.size}"

    puts "\n[思考テキスト]:"
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
rescue => e
  puts "エラー: #{e.message}"
end

# 例5: parts_with_signatures メソッドのテスト
puts "\n\n【例5】parts_with_signatures メソッドのテスト"
puts "-" * 60
begin
  response = client.generate_content(
    "福岡の天気は？",
    model: "gemini-2.5-flash",
    thinking_config: 8192,
    tools: [weather_function]
  )

  if response.has_thoughts?
    puts "元のparts:"
    response.parts.each_with_index do |part, i|
      puts "  Part #{i + 1}:"
      puts "    Keys: #{part.keys.inspect}"
      puts "    thought: #{part['thought']}" if part.key?('thought')
      puts "    thoughtSignature: #{part['thoughtSignature'] ? '存在' : 'なし'}"
    end

    puts "\nparts_with_signatures（会話履歴用）:"
    response.parts_with_signatures.each_with_index do |part, i|
      puts "  Part #{i + 1}:"
      puts "    Keys: #{part.keys.inspect}"
      puts "    thought: #{part['thought']}" if part.key?('thought')
      puts "    thoughtSignature: #{part['thoughtSignature'] ? '存在' : 'なし'}"
    end

    puts "\ncontent_for_history:"
    content = response.content_for_history
    puts "  role: #{content['role']}"
    puts "  parts count: #{content['parts'].size}"
  else
    puts "思考partsが含まれていません"
  end
rescue => e
  puts "エラー: #{e.message}"
end

puts "\n" + "=" * 60
puts "デモ完了"
puts "=" * 60
