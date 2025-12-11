require "gemini"

# Initialize Gemini client
api_key = ENV['GEMINI_API_KEY'] || raise("Please set the GEMINI_API_KEY environment variable")
client = Gemini::Client.new(api_key)

# Define function declarations using the new DSL
tools = Gemini::ToolDefinition.new do
  function :get_current_weather, description: "Get the current weather information" do
    property :location, type: :string, description: "City name, e.g., Tokyo", required: true
  end
end

# User prompt
user_prompt = "Tell me the current weather in Tokyo."

# Send request to Gemini API
response = client.generate_content(
  user_prompt,
  model: "gemini-2.5-flash",
  tools: tools
)

# Print Gemini's response
puts "Gemini Response:"

# Parse the functionCall if included in the response
unless response.function_calls.empty?
  function_call = response.function_calls
  puts "Function name to call: #{function_call[0]["name"]}"
  puts "Function arguments: #{function_call[0]["args"]}"
end
