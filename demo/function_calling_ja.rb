require "gemini"

# Geminiクライアントの初期化
api_key = ENV['GEMINI_API_KEY'] || raise("Please set the GEMINI_API_KEY environment variable")
client = Gemini::Client.new(api_key)

# Function Calling用関数定義
tools = Gemini::ToolDefinition.new do
  function :get_current_weather, description: "現在の天気を取得する" do
    property :location, type: :string, description: "都市名、例：東京", required: true
  end
end

# ユーザーからのプロンプト
user_prompt = "東京の現在の天気を教えて"

# Gemini APIへリクエスト送信
response = client.generate_content(
  user_prompt,
  model: "gemini-2.0-flash",
  tools: tools
)

# レスポンスを確認
puts "Geminiのレスポンス: "

# レスポンスにfunctionCallが含まれていればパース
unless response.function_calls.empty?
  function_call = response.function_calls
  puts "呼び出す関数名: #{function_call[0]["name"]}"
  puts "関数の引数: #{function_call[0]["args"]}"
end
