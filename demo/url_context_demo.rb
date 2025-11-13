require 'bundler/setup'
require 'gemini'

# Get URL and options from command line arguments
url = nil
use_url_context = true

ARGV.each do |arg|
  if arg == '--no-context' || arg == '--off'
    use_url_context = false
  elsif !arg.start_with?('--')
    url = arg
  end
end

unless url
  puts "Usage: ruby url_context_demo.rb <URL> [--no-context]"
  puts "Example: ruby url_context_demo.rb https://www.ruby-lang.org/"
  puts "         ruby url_context_demo.rb https://www.ruby-lang.org/ --no-context"
  puts ""
  puts "Options:"
  puts "  --no-context  Run without URL Context"
  exit 1
end

api_key = ENV['GEMINI_API_KEY'] || raise("Please set the GEMINI_API_KEY environment variable")

begin
  puts "Initializing Gemini client..."
  client = Gemini::Client.new(api_key)

  puts "Gemini URL Context Demo"
  puts "==================================="
  puts "URL: #{url}"
  puts "URL Context: #{use_url_context ? 'ON' : 'OFF'}"
  puts "==================================="

  # Summarize the URL content
  puts "\nSummarizing the URL content..."
  response = client.generate_content(
    "Please summarize the content of this page in detail: #{url}",
    model: "gemini-2.5-flash",
    url_context: use_url_context
  )

  if response.success?
    puts "\nSummary:"
    puts response.text

    # Display URL Context metadata
    if response.url_context?
      puts "\n--- URL Context Information ---"
      puts "Retrieved URLs: #{response.retrieved_urls.length}"

      response.url_retrieval_statuses.each_with_index do |url_info, i|
        puts "\n#{i+1}. URL: #{url_info[:url]}"
        puts "   Status: #{url_info[:status]}"
        puts "   Title: #{url_info[:title]}" if url_info[:title]
      end
    end
  else
    puts "Error: #{response.error}"
  end

  puts "\n==================================="
  puts "Demo completed"

rescue StandardError => e
  puts "\nAn error occurred: #{e.message}"
  puts e.backtrace.join("\n") if ENV["DEBUG"]
end
