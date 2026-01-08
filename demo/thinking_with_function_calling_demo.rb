require 'bundler/setup'
require 'gemini'

# Get API key from environment variable
api_key = ENV['GEMINI_API_KEY'] || raise("Please set the GEMINI_API_KEY environment variable")
client = Gemini::Client.new(api_key)

puts "=" * 60
puts "Gemini 2.5 Thinking Model + Function Calling Demo"
puts "=" * 60
puts "Note: In Gemini 2.5, Thought Signatures are only returned in requests with function declarations"
puts "=" * 60

# Function definition (calculator functions)
calculator_function = {
  function_declarations: [
    {
      name: "calculate",
      description: "Perform arithmetic operations. For complex calculations, call multiple times.",
      parameters: {
        type: "object",
        properties: {
          operation: {
            type: "string",
            description: "Operation type",
            enum: ["add", "subtract", "multiply", "divide", "power", "sqrt"]
          },
          a: {
            type: "number",
            description: "First operand"
          },
          b: {
            type: "number",
            description: "Second operand (not required for sqrt)"
          }
        },
        required: ["operation", "a"]
      }
    },
    {
      name: "compare_numbers",
      description: "Compare two numbers",
      parameters: {
        type: "object",
        properties: {
          a: {
            type: "number",
            description: "First number to compare"
          },
          b: {
            type: "number",
            description: "Second number to compare"
          }
        },
        required: ["a", "b"]
      }
    }
  ]
}

# Example 1: Request without Function Calling (for comparison)
puts "\n[Example 1] Without Function Calling (for comparison)"
puts "-" * 60
puts "【Purpose】"
puts "  Verify that even with thinking mode enabled, without function declarations,"
puts "  Thought Signatures are NOT returned (Gemini 2.5 constraint)."
puts ""
puts "【Expected Results】"
puts "  - has_thoughts? may be true or false (thought text may exist)"
puts "  - thought_signatures is empty array (Gemini 2.5 constraint)"
puts "  - Normal text response is obtained"
puts ""
puts "【Running】Requesting without function declarations..."
puts "-" * 60
begin
  response = client.generate_content(
    "You have three investment options: A) Initial investment of $10,000 at 5% annual rate, B) Initial investment of $8,000 at 7% annual rate, C) Initial investment of $12,000 at 4% annual rate. Which one will have the highest profit after 10 years?",
    model: "gemini-2.5-flash",
    thinking_config: 8192
  )

  puts "has_thoughts?: #{response.has_thoughts?}"
  puts "thought_signatures count: #{response.thought_signatures.size}"
  puts "text: #{response.text}"

  puts "\n【Result Explanation】"
  if response.thought_signatures.empty?
    puts "  ✓ As expected, Thought Signatures is empty"
    puts "  → In Gemini 2.5, signatures are not returned without function declarations"
  else
    puts "  ! Unexpected: Thought Signatures are included (#{response.thought_signatures.size} items)"
  end
  if response.has_thoughts?
    puts "  ✓ Thought text itself is included"
  end
rescue => e
  puts "Error: #{e.message}"
end

# Example 2: Request with Function Calling (should return Thought Signatures)
puts "\n\n[Example 2] With Function Calling (obtaining Thought Signatures)"
puts "-" * 60
puts "【Purpose】"
puts "  Verify that Thought Signatures are correctly obtained with function declarations."
puts "  This is the ONLY way to get Thought Signatures in Gemini 2.5."
puts "  Use complex question (requiring comparison/judgment) to trigger thinking process."
puts ""
puts "【Expected Results】"
puts "  - has_thought_signatures? returns true (important)"
puts "  - thought_signatures contains one or more signatures"
puts "  - Function calls are planned (add, multiply, divide, etc.)"
puts "  - Note: has_thoughts? is often false (Gemini 2.5 spec)"
puts "  - If Thought Signatures are obtained, thinking process is working"
puts ""
puts "【Running】Requesting function calls with complex question..."
puts "-" * 60
begin
  response = client.generate_content(
    "I have three numbers: 123, 456, and 789. Calculate their sum, then double the result, and finally divide by 100. Tell me the final value.",
    model: "gemini-2.5-flash",
    thinking_config: 8192,
    tools: [calculator_function]
  )

  puts "has_thoughts?: #{response.has_thoughts?}"
  puts "has_thought_signatures?: #{response.has_thought_signatures?}"
  puts "thought_signatures count: #{response.thought_signatures.size}"

  if response.has_thoughts?
    puts "\n[Thinking Process]:"
    puts response.thought_text

    puts "\n[Thought Signatures]:"
    response.thought_signatures.each_with_index do |sig, i|
      puts "  Signature #{i + 1}:"
      puts "    Text: #{sig[:text][0..100]}..."
      puts "    Signature: #{sig[:signature][0..50]}..."
    end
  end

  puts "\n[Function Calls]:"
  if response.function_calls.any?
    response.function_calls.each do |fc|
      puts "  Function: #{fc['name']}"
      puts "  Args: #{fc['args'].inspect}"
    end
  else
    puts "  None"
  end

  puts "\n[Text Response]:"
  puts response.text if response.text && !response.text.empty?

  puts "\n[Full Content (thought parts prefixed with [THOUGHT])]:"
  puts response.full_content
rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace.first(5)
end

# Example 3: Conversation class with function calls (automatic Thought Signatures preservation)
puts "\n\n[Example 3] Conversation class + Function Calling (automatic signature preservation)"
puts "-" * 60
puts "【Purpose】"
puts "  Verify that when using Conversation class with function calling,"
puts "  Thought Signatures are automatically saved in conversation history."
puts ""
puts "【Expected Results】"
puts "  - Response contains Thought Signatures"
puts "  - Signatures are preserved in conversation history"
puts "  - Signatures become available for next question"
puts ""
puts "【Running】Asking question while managing conversation history..."
puts "-" * 60
begin
  conversation = Gemini::Conversation.new(
    client: client,
    model: "gemini-2.5-flash",
    thinking_config: 8192
  )

  # First message (with function declarations)
  puts "\n[Question 1] Compound interest calculation: Invest $10,000 at 5% for 10 years?"
  response1 = conversation.send_message(
    "If I invest $10,000 at 5% annual interest for 10 years with compound interest, how much will I have in the end? Show me the calculation process.",
    tools: [calculator_function]
  )

  puts "has_thoughts?: #{response1.has_thoughts?}"
  puts "has_thought_signatures?: #{response1.has_thought_signatures?}"
  puts "thought_signatures: #{response1.thought_signatures.size} items"

  if response1.function_calls.any?
    puts "Function calls:"
    response1.function_calls.each do |fc|
      puts "  - #{fc['name']}: #{fc['args'].inspect}"
    end
  end

  # Normally you would execute the function and return results here, but skipping for demo
  # In a real app:
  # 1. Check response1.function_calls
  # 2. Execute each function
  # 3. Return results with conversation.send_message

  puts "\n[Conversation history count]: #{conversation.get_history.size} items"

  # Check if Thought Signatures are preserved in history
  if conversation.get_history.size > 1
    model_response = conversation.get_history[1]
    puts "[Are signatures preserved in history?]:"
    if model_response && model_response["parts"]
      has_sig = model_response["parts"].any? { |p| p.key?("thoughtSignature") }
      puts "  #{has_sig ? 'Yes - signatures are preserved' : 'No'}"
    end
  end

  puts "\n【Result Explanation】"
  if response1.has_thought_signatures?
    puts "  ✓ Thought Signatures obtained successfully"
  end
  if conversation.get_history.size > 1
    model_response = conversation.get_history[1]
    if model_response && model_response["parts"]
      has_sig = model_response["parts"].any? { |p| p.key?("thoughtSignature") }
      if has_sig
        puts "  ✓ Signatures are automatically preserved in conversation history"
        puts "  → Conversation class automatically manages signatures"
        puts "  → This maintains context across multiple turns of conversation"
      end
    end
  end
rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace.first(5)
end

# Example 4: Multiple function declarations and complex question
puts "\n\n[Example 4] Multiple functions + complex question"
puts "-" * 60
puts "【Purpose】"
puts "  Verify that thinking process works properly with complex questions"
puts "  requiring multiple function calls."
puts ""
puts "【Expected Results】"
puts "  - Larger thinking_budget (16384) provides more detailed thinking"
puts "  - Multiple calculations are executed in order"
puts "  - thought_parts and non_thought_parts are properly separated"
puts "  - Comparison and judgment of calculation results are performed"
puts ""
puts "【Running】Processing complex question..."
puts "-" * 60
begin
  response = client.generate_content(
    "Solve this problem: (15 × 23) + (89 × 12) - (45 × 7). Calculate the result and determine if the value is greater or less than 1000.",
    model: "gemini-2.5-flash",
    thinking_config: 16384,  # Larger budget to encourage thinking
    tools: [calculator_function]
  )

  puts "has_thoughts?: #{response.has_thoughts?}"

  if response.has_thoughts?
    puts "\n[Thought Details]:"
    puts "  thought_parts count: #{response.thought_parts.size}"
    puts "  non_thought_parts count: #{response.non_thought_parts.size}"
    puts "  thought_signatures count: #{response.thought_signatures.size}"

    puts "\n[Thought Text]:"
    puts response.thought_text[0..200] + "..."
  end

  puts "\n[Function Calls]:"
  if response.function_calls.any?
    response.function_calls.each_with_index do |fc, i|
      puts "  #{i + 1}. #{fc['name']}"
      puts "     Args: #{fc['args'].inspect}"
    end
  else
    puts "  None"
  end

  puts "\n【Result Explanation】"
  if response.has_thoughts?
    puts "  ✓ Detailed thinking process obtained with thinking_budget: 16384"
    puts "  ✓ #{response.thought_parts.size} thought_parts and #{response.non_thought_parts.size} non_thought_parts"
  end
  if response.function_calls.any?
    puts "  ✓ #{response.function_calls.size} function calls planned"
    puts "  → Model decomposed complex request into multiple function calls"
  end
rescue => e
  puts "Error: #{e.message}"
end

# Example 5: Testing parts_with_signatures method
puts "\n\n[Example 5] Testing parts_with_signatures method"
puts "-" * 60
puts "【Purpose】"
puts "  Verify that parts_with_signatures method excludes thought parts"
puts "  while preserving Thought Signatures."
puts ""
puts "【Expected Results】"
puts "  - Original parts contain thought parts and thoughtSignatures"
puts "  - parts_with_signatures excludes thought parts"
puts "  - parts_with_signatures still preserves thoughtSignatures"
puts "  - content_for_history provides content for conversation history"
puts ""
puts "【Running】Testing parts conversion..."
puts "-" * 60
begin
  response = client.generate_content(
    "Perform the following calculations step by step: Calculate √144, multiply the result by 5, then subtract 20. What is the final value?",
    model: "gemini-2.5-flash",
    thinking_config: 8192,
    tools: [calculator_function]
  )

  if response.has_thoughts?
    puts "Original parts:"
    response.parts.each_with_index do |part, i|
      puts "  Part #{i + 1}:"
      puts "    Keys: #{part.keys.inspect}"
      puts "    thought: #{part['thought']}" if part.key?('thought')
      puts "    thoughtSignature: #{part['thoughtSignature'] ? 'present' : 'none'}"
    end

    puts "\nparts_with_signatures (for conversation history):"
    response.parts_with_signatures.each_with_index do |part, i|
      puts "  Part #{i + 1}:"
      puts "    Keys: #{part.keys.inspect}"
      puts "    thought: #{part['thought']}" if part.key?('thought')
      puts "    thoughtSignature: #{part['thoughtSignature'] ? 'present' : 'none'}"
    end

    puts "\ncontent_for_history:"
    content = response.content_for_history
    puts "  role: #{content['role']}"
    puts "  parts count: #{content['parts'].size}"

    puts "\n【Result Explanation】"
    orig_count = response.parts.size
    preserved_count = response.parts_with_signatures.size
    puts "  ✓ Original parts: #{orig_count}, parts_with_signatures: #{preserved_count}"
    if orig_count > preserved_count
      puts "  ✓ Thought parts (thought: true) were excluded"
    end
    has_sig_in_preserved = response.parts_with_signatures.any? { |p| p.key?('thoughtSignature') }
    if has_sig_in_preserved
      puts "  ✓ thoughtSignature is preserved"
      puts "  → When saving to conversation history, thought content is excluded but signatures are preserved"
      puts "  → This reduces token usage while maintaining context continuity"
    end
  else
    puts "No thought parts included"
  end
rescue => e
  puts "Error: #{e.message}"
end

puts "\n" + "=" * 60
puts "Demo completed"
puts "=" * 60
puts ""
puts "【Summary】"
puts "This demo verified the following:"
puts "  1. Without function declarations, Thought Signatures are not returned in Gemini 2.5"
puts "  2. With function declarations, Thought Signatures are correctly obtained"
puts "  3. Conversation class automatically manages signatures"
puts "  4. Function calls are properly planned even with complex calculation problems"
puts "  5. parts_with_signatures excludes thought content while preserving signatures"
puts ""
puts "【Key Points】"
puts "  • Function declarations are required to get Thought Signatures in Gemini 2.5"
puts "  • Using Conversation class automates signature management"
puts "  • Saving only signatures (not thought content) in conversation history saves tokens"
puts "  • Calculation and logical reasoning questions are more likely to trigger thinking process"
puts ""
puts "See the 'Function Calling and Thought Signatures' section in README for details."
