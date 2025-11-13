require 'bundler/setup'
require 'gemini'

api_key = ENV['GEMINI_API_KEY'] || raise("Please set the GEMINI_API_KEY environment variable")

begin
  puts "Initializing Gemini client..."
  client = Gemini::Client.new(api_key)
  
  puts "Gemini Grounding Search Demo"
  puts "==================================="

  # Use Google Search to get real-time information
  response = client.generate_content(
    "Who won the euro 2024?",
    model: "gemini-2.5-flash",
    tools: [{ google_search: {} }]
  )
  
  if response.success?
    puts "\nAnswer:"
    puts response.text

    # Display grounding information using simplified methods
    if response.grounded?
      puts "\n--- Grounding Information ---"
      puts "Sources: #{response.grounding_sources.length} references"

      response.grounding_sources.each_with_index do |source, i|
        puts "\n#{i+1}. #{source[:title]}"
        puts "   URL: #{source[:url]}"
      end
    end
  else
    puts "Error: #{response.error}"
  end
  
  puts "\n==================================="
  
  # Another example: Get latest news
  puts "\nExample of getting latest information:"
  response2 = client.generate_content(
    "What are the latest tech news from Japan?",
    model: "gemini-2.0-flash-lite",
    tools: [{ google_search: {} }]
  )
  
  if response2.success?
    puts response2.text
  end
  
  puts "\nDemo completed"

rescue StandardError => e
  puts "\nAn error occurred: #{e.message}"
  puts e.backtrace.join("\n") if ENV["DEBUG"]
end