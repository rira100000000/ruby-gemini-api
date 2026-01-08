require 'bundler/setup'
require 'gemini'

# Get API key from environment variable
api_key = ENV['GEMINI_API_KEY'] || raise("Please set the GEMINI_API_KEY environment variable")
client = Gemini::Client.new(api_key)

puts "=" * 60
puts "Gemini Thinking Model Demo"
puts "=" * 60
puts ""
puts "【IMPORTANT NOTICE】"
puts "  This demo does NOT use Function Calling."
puts "  Therefore, Gemini 2.5 will NOT return any Thought Signatures."
puts ""
puts "  To get Thought Signatures with Gemini 2.5:"
puts "  → See thinking_with_function_calling_demo.rb"
puts ""
puts "  What you can verify in this demo:"
puts "  - Thought process text (thought_text)"
puts "  - Presence of thoughts (has_thoughts?)"
puts "  - Response without thoughts (text, non_thought_text)"
puts "=" * 60

# Example 1: Basic thinking mode (Gemini 2.5 - thinkingBudget)
puts "\n[Example 1] Basic thinking mode (Gemini 2.5)"
puts "-" * 60
puts "【Purpose】"
puts "  Verify basic thinking mode operation with thinking_config."
puts "  Specifying a number (8192) treats it as thinkingBudget."
puts ""
puts "【Expected Results】"
puts "  - has_thoughts? returns true"
puts "  - thought_text retrieves the thinking process"
puts "  - text retrieves only the final answer without thoughts"
puts "  - thought_signatures is empty (no function calling)"
puts ""
puts "【Running】Solving math problem in thinking mode..."
puts "-" * 60
begin
  response = client.generate_content(
    "Solve this problem: If you double a number and add 7, you get 23. What is that number?",
    model: "gemini-2.5-flash",
    thinking_config: 8192  # For Gemini 2.5: simple thinkingBudget specification
  )

  if response.has_thoughts?
    puts "\n[Thinking Process]:"
    puts response.thought_text
    puts "\n[Final Answer]:"
    puts response.text  # Excludes thoughts by default
    puts "\n【Result Explanation】"
    puts "  ✓ Thinking process retrieved successfully"
    puts "  ✓ thought_text shows internal calculation process"
    puts "  ✓ text returns only the final answer without thoughts"
    if response.thought_signatures.empty?
      puts "  ✓ Thought Signatures is empty (normal for no function calling)"
    end
  else
    puts response.text
    puts "\n【Result Explanation】"
    puts "  ✗ No thought parts included"
    puts "  → thinking_config may not be set correctly"
  end
rescue => e
  puts "Error: #{e.message}"
  puts "Note: Requires Gemini 2.5 or later model"
end

# Example 2: Detailed configuration (Gemini 2.5 - explicit thinkingBudget)
puts "\n\n[Example 2] Detailed configuration (explicit thinkingBudget)"
puts "-" * 60
begin
  response = client.generate_content(
    "Find the 10th number in the Fibonacci sequence",
    model: "gemini-2.5-flash",
    thinking_config: {
      thinking_budget: 16384
    }
  )

  if response.has_thoughts?
    puts "\n[Thinking Process]:"
    puts response.thought_text
    puts "\n[Final Answer]:"
    puts response.non_thought_text
    puts "\n[Thought Signatures]:"
    puts response.thought_signatures.inspect
  else
    puts response.text
  end
rescue => e
  puts "Error: #{e.message}"
end

# Example 3: Thinking budget specification for Gemini 2.5
puts "\n\n[Example 3] Thinking budget specification (Gemini 2.5)"
puts "-" * 60
begin
  response = client.generate_content(
    "Explain how quantum computers work in simple terms",
    model: "gemini-2.5-flash",
    thinking_config: 2048  # Simple specification of thinking_budget
  )

  if response.has_thoughts?
    puts "\n[With thoughts]"
    puts "Thought: #{response.thought_text}"
    puts "Answer: #{response.text}"
  else
    puts response.text
  end
rescue => e
  puts "Error: #{e.message}"
end

# Example 4: Conversation class with conversation history management (automatic Thought Signatures preservation)
puts "\n\n[Example 4] Conversation history management (automatic Thought Signatures preservation)"
puts "-" * 60
begin
  # Conversation class automatically manages signatures
  conversation = Gemini::Conversation.new(
    client: client,
    model: "gemini-2.5-flash",
    thinking_config: 8192  # For Gemini 2.5: thinkingBudget
  )

  # First message
  puts "\n[Question 1] What is 123 × 456?"
  response1 = conversation.send_message("What is 123 × 456?")

  if response1.has_thoughts?
    puts "[Thought] #{response1.thought_text[0..100]}..."
  end
  puts "[Answer] #{response1.text}"

  # Second message (Thought Signatures are automatically preserved)
  puts "\n[Question 2] What is that result divided by 7?"
  response2 = conversation.send_message("What is that result divided by 7?")

  if response2.has_thoughts?
    puts "[Thought] #{response2.thought_text[0..100]}..."
  end
  puts "[Answer] #{response2.text}"

  # Check conversation history
  puts "\n[Conversation history count]: #{conversation.get_history.size} items"
rescue => e
  puts "Error: #{e.message}"
end

# Example 5: Streaming response with thoughts
puts "\n\n[Example 5] Streaming (with thoughts)"
puts "-" * 60
begin
  puts "Count from 1 to 5 and explain why:"

  client.generate_content(
    "Count from 1 to 5 and explain why you do it that way",
    model: "gemini-2.5-flash",
    thinking_config: 8192  # For Gemini 2.5
  ) do |chunk_text, chunk|
    # Check if it's a thought part
    part = chunk.dig("candidates", 0, "content", "parts", 0)
    if part && part["thought"] == true
      print "[Thought] "
    end
    print chunk_text
  end
  puts "\n"
rescue => e
  puts "Error: #{e.message}"
end

# Example 6: Backward compatibility (works without thinking_config)
puts "\n\n[Example 6] Backward compatibility (without thinking_config)"
puts "-" * 60
begin
  # Normal request without thinking_config
  response = client.generate_content(
    "Hello",
    model: "gemini-2.5-flash"
    # No thinking_config
  )

  puts "has_thoughts?: #{response.has_thoughts?}"
  puts "text: #{response.text}"
rescue => e
  puts "Error: #{e.message}"
end

# Example 7: Visual identification of thought parts with full_content
puts "\n\n[Example 7] full_content method (visualizing thought parts)"
puts "-" * 60
begin
  response = client.generate_content(
    "What is 2 to the power of 10?",
    model: "gemini-2.5-flash",
    thinking_config: 8192
  )

  puts "\nfull_content (thought parts prefixed with [THOUGHT]):"
  puts response.full_content
rescue => e
  puts "Error: #{e.message}"
end

puts "\n" + "=" * 60
puts "Demo completed"
puts "=" * 60
