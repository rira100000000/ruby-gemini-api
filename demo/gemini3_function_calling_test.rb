require 'bundler/setup'
require 'gemini'

# Get API key from environment variable
api_key = ENV['GEMINI_API_KEY'] || raise("Please set the GEMINI_API_KEY environment variable")
client = Gemini::Client.new(api_key)

puts "=" * 60
puts "Gemini 3 + Function Calling + Thought Signatures Test"
puts "=" * 60
puts "Purpose: Verify that signatures are correctly preserved in function call parts"
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
    }
  ]
}

# Test 1: Gemini 3 + Function Calling
puts "\n[Test 1] Gemini 3 + Function Calling (checking signature location)"
puts "-" * 60
puts "【Test Purpose】"
puts "  Verify that in Gemini 3 with function calling, Thought Signature"
puts "  is included in the first function call part."
puts ""
puts "【Expected Results】"
puts "  - Thought parts (thought: true) are included"
puts "  - First function call part has thoughtSignature key"
puts "  - parts_with_signatures also preserves signature in function call part"
puts ""
puts "【Running】Sending request with function calling to Gemini 3..."
puts "-" * 60
begin
  response = client.generate_content(
    "I have three numbers: 123, 456, and 789. Calculate their sum, then double the result, and finally divide by 100. Tell me the final value.",
    model: "gemini-3-flash-preview",
    thinking_config: { thinking_level: "high", include_thoughts: true },
    tools: [calculator_function]
  )

  puts "has_thoughts?: #{response.has_thoughts?}"
  puts "has_thought_signatures?: #{response.has_thought_signatures?}"
  puts "thought_signatures count: #{response.thought_signatures.size}"

  puts "\n[All Parts Details]:"
  response.parts.each_with_index do |part, i|
    puts "  Part #{i + 1}:"
    puts "    Keys: #{part.keys.inspect}"
    puts "    thought: #{part['thought']}" if part.key?('thought')
    puts "    thoughtSignature: #{part['thoughtSignature'] ? 'present' : 'none'}"
    puts "    functionCall: #{part['functionCall']['name']}" if part.key?('functionCall')
    puts "    text preview: #{part['text'][0..50]}..." if part.key?('text') && part['text']
  end

  puts "\n[parts_with_signatures (for conversation history)]:"
  response.parts_with_signatures.each_with_index do |part, i|
    puts "  Part #{i + 1}:"
    puts "    Keys: #{part.keys.inspect}"
    puts "    thought: #{part['thought']}" if part.key?('thought')
    puts "    thoughtSignature: #{part['thoughtSignature'] ? 'present' : 'none'}"
    puts "    functionCall: #{part['functionCall']['name']}" if part.key?('functionCall')
  end

  puts "\n[Verification Results]:"
  # Check if the first function call part has a signature
  first_fc_part = response.parts.find { |p| p.key?('functionCall') }
  if first_fc_part
    puts "  ✓ Function call part found"
    if first_fc_part.key?('thoughtSignature')
      puts "  ✓ First function call part contains signature (as per Gemini 3 spec)"
    else
      puts "  ✗ First function call part has no signature"
    end

    # Check if it's preserved in parts_with_signatures
    fc_in_preserved = response.parts_with_signatures.find { |p| p.key?('functionCall') }
    if fc_in_preserved && fc_in_preserved.key?('thoughtSignature')
      puts "  ✓ Signature is preserved in parts_with_signatures"
    elsif fc_in_preserved
      puts "  ✗ Signature is lost in parts_with_signatures"
    end
  else
    puts "  ✗ Function call part not found"
  end

rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace.first(5)
end

# Test 2: Gemini 3 + Function Calling + Conversation (conversation history management)
puts "\n\n[Test 2] Gemini 3 + Conversation (automatic signature preservation)"
puts "-" * 60
puts "【Test Purpose】"
puts "  Verify that when using Conversation class, Thought Signature in function call part"
puts "  is correctly saved in conversation history."
puts ""
puts "【Expected Results】"
puts "  - Response contains Thought Signatures"
puts "  - Signature is saved in function call part of conversation history"
puts "  - Signature becomes available for next turn"
puts ""
puts "【Running】Asking question with Conversation class..."
puts "-" * 60
begin
  conversation = Gemini::Conversation.new(
    client: client,
    model: "gemini-3-flash-preview",
    thinking_config: { thinking_level: "high", include_thoughts: true }
  )

  # First message (with function declarations)
  puts "\n[Question 1] Compound interest calculation: Invest $10,000 at 5% for 10 years?"
  response1 = conversation.send_message(
    "If I invest $10,000 at 5% annual interest for 10 years with compound interest, how much will I have in the end? Show me the calculation process.",
    tools: [calculator_function]
  )

  puts "has_thoughts?: #{response1.has_thoughts?}"
  puts "has_thought_signatures?: #{response1.has_thought_signatures?}"

  if response1.function_calls.any?
    puts "Function calls: #{response1.function_calls.map { |fc| fc['name'] }.join(', ')}"
  end

  puts "\n[Checking Conversation History]:"
  history = conversation.get_history
  puts "  History count: #{history.size}"

  if history.size > 1
    model_response = history[1]  # Model's response
    puts "  Model response parts count: #{model_response['parts'].size}"

    # Find the function call part
    fc_part = model_response['parts'].find { |p| p.key?('functionCall') }
    if fc_part
      puts "  ✓ Function call part saved in history"
      if fc_part.key?('thoughtSignature')
        puts "  ✓ Signature preserved in function call part"
        puts "    Signature (first 50 chars): #{fc_part['thoughtSignature'][0..50]}..."
      else
        puts "  ✗ Function call part has no signature"
      end
    else
      puts "  ✗ Function call part not found in history"
    end
  end

rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace.first(5)
end

# Test 3: Gemini 3 without function calls
puts "\n\n[Test 3] Gemini 3 without Function Calling"
puts "-" * 60
puts "【Test Purpose】"
puts "  Verify that in Gemini 3 without function calling, Thought Signature"
puts "  is included in the last part."
puts ""
puts "【Expected Results】"
puts "  - Thought parts (thought: true) are included"
puts "  - Last part has thoughtSignature key"
puts "  - This is Gemini 3 spec (when no function calling)"
puts ""
puts "【Running】Requesting without function declarations..."
puts "-" * 60
begin
  response = client.generate_content(
    "Calculate 2 to the power of 10, then explain if this number is closer to 1000 or 2000, and why.",
    model: "gemini-3-flash-preview",
    thinking_config: { thinking_level: "high", include_thoughts: true }
    # No tools
  )

  puts "has_thoughts?: #{response.has_thoughts?}"
  puts "has_thought_signatures?: #{response.has_thought_signatures?}"

  puts "\n[All Parts Details]:"
  response.parts.each_with_index do |part, i|
    puts "  Part #{i + 1}:"
    puts "    Keys: #{part.keys.inspect}"
    puts "    thought: #{part['thought']}" if part.key?('thought')
    puts "    thoughtSignature: #{part['thoughtSignature'] ? 'present' : 'none'}"
    puts "    text preview: #{part['text'][0..50]}..." if part.key?('text') && part['text']
  end

  puts "\n[Verification Results]:"
  last_part = response.parts.last
  if last_part && last_part.key?('thoughtSignature')
    puts "  ✓ Last part contains signature (as per Gemini 3 spec)"
  else
    puts "  ✗ Last part has no signature"
  end

rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace.first(5)
end

puts "\n" + "=" * 60
puts "Test completed"
puts "=" * 60
