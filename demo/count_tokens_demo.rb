require 'bundler/setup'
require 'gemini'

api_key = ENV['GEMINI_API_KEY'] || 'YOUR_API_KEY_HERE'
client = Gemini::Client.new(api_key)

puts "=== Simple text ==="
response = client.count_tokens("The quick brown fox jumps over the lazy dog.")
if response.success?
  puts "totalTokens: #{response.count_tokens}"
  puts "promptTokensDetails: #{response.prompt_tokens_details.inspect}"
else
  puts "Error: #{response.error}"
end

puts
puts "=== Multi-turn chat history ==="
response = client.count_tokens(
  contents: [
    { role: "user", parts: [{ text: "Hi, my name is Bob." }] },
    { role: "model", parts: [{ text: "Hi Bob!" }] },
    { role: "user", parts: [{ text: "What's the weather like today?" }] }
  ]
)
puts "totalTokens: #{response.count_tokens}"

puts
puts "=== With system instruction and tools ==="
response = client.count_tokens(
  "What is the weather in Tokyo?",
  system_instruction: "You are a concise weather assistant.",
  tools: [
    {
      function_declarations: [
        {
          name: "get_weather",
          description: "Get the current weather for a city.",
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
puts "totalTokens (with system_instruction + tools): #{response.count_tokens}"

puts
puts "=== Different model ==="
response = client.count_tokens("Hello world", model: "gemini-2.5-pro")
puts "totalTokens (gemini-2.5-pro): #{response.count_tokens}"
