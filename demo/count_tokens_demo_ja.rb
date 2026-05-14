require 'bundler/setup'
require 'gemini'

api_key = ENV['GEMINI_API_KEY'] || 'YOUR_API_KEY_HERE'
client = Gemini::Client.new(api_key)

puts "=== シンプルなテキスト ==="
response = client.count_tokens("素早い茶色の狐は怠惰な犬を飛び越える。")
if response.success?
  puts "合計トークン数: #{response.count_tokens}"
  puts "モダリティ別内訳: #{response.prompt_tokens_details.inspect}"
else
  puts "エラー: #{response.error}"
end

puts
puts "=== マルチターンの会話履歴 ==="
response = client.count_tokens(
  contents: [
    { role: "user", parts: [{ text: "こんにちは、私はボブです。" }] },
    { role: "model", parts: [{ text: "こんにちはボブさん！" }] },
    { role: "user", parts: [{ text: "今日の天気はどうですか？" }] }
  ]
)
puts "合計トークン数: #{response.count_tokens}"

puts
puts "=== システム指示とツール込みのカウント ==="
response = client.count_tokens(
  "東京の天気を教えて。",
  system_instruction: "あなたは簡潔に答える天気アシスタントです。",
  tools: [
    {
      function_declarations: [
        {
          name: "get_weather",
          description: "指定された都市の現在の天気を取得する。",
          parameters: {
            type: "object",
            properties: { city: { type: "string" } },
            required: ["city"]
          }
        }
      ]
    }
  ]
)
puts "合計トークン数 (system_instruction + tools 込み): #{response.count_tokens}"

puts
puts "=== 別モデル ==="
response = client.count_tokens("こんにちは世界", model: "gemini-2.5-pro")
puts "合計トークン数 (gemini-2.5-pro): #{response.count_tokens}"
