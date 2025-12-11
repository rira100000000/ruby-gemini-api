require 'bundler/setup'
require 'gemini'
require 'logger'

# Logger setup
logger = Logger.new(STDOUT)
logger.level = Logger::INFO

# Get API key from environment variable
api_key = ENV['GEMINI_API_KEY'] || raise("Please set GEMINI_API_KEY environment variable")

begin
  # Initialize client
  logger.info "Initializing Gemini client..."
  client = Gemini::Client.new(api_key)

  puts "Video Understanding Demo"
  puts "==============================================="

  # Process command line arguments
  if ARGV.empty?
    puts "Usage:"
    puts "  File analysis:    ruby video_demo.rb <video_file_path>"
    puts "  YouTube analysis: ruby video_demo.rb --youtube <YouTube URL>"
    puts ""
    puts "Examples:"
    puts "  ruby video_demo.rb sample.mp4"
    puts "  ruby video_demo.rb --youtube https://www.youtube.com/watch?v=XXXXX"
    puts ""
    puts "Supported video formats: MP4, MPEG, MOV, AVI, FLV, MPG, WebM, WMV, 3GPP"
    exit 1
  end

  # Start time
  start_time = Time.now

  if ARGV[0] == "--youtube"
    # YouTube URL analysis mode
    youtube_url = ARGV[1] || raise("Please specify a YouTube URL")

    puts "Analyzing YouTube video..."
    puts "URL: #{youtube_url}"
    puts "==============================================="

    # Get video description
    puts "\n=== Video Description ==="
    response = client.video.describe(youtube_url: youtube_url, language: "en")

    if response.valid?
      puts response.text
    else
      puts "Error: #{response.error || 'Unknown error'}"
    end

    # Custom question
    puts "\n=== Question About Video ==="
    question = "What are the three main points of this video?"
    puts "Question: #{question}"
    puts ""

    response = client.video.ask(youtube_url: youtube_url, question: question)

    if response.valid?
      puts response.text
    else
      puts "Error: #{response.error || 'Unknown error'}"
    end

  else
    # Local file analysis mode
    video_file_path = ARGV[0]

    # Check if file exists
    unless File.exist?(video_file_path)
      raise "File not found: #{video_file_path}"
    end

    # Display file information
    file_size = File.size(video_file_path) / 1024.0 / 1024.0 # In MB
    file_extension = File.extname(video_file_path)
    puts "File: #{File.basename(video_file_path)}"
    puts "Size: #{file_size.round(2)} MB"
    puts "Type: #{file_extension}"
    puts "==============================================="

    # Choose processing method based on file size
    if file_size < 20
      puts "Processing as inline data (under 20MB)..."

      # Process small files as inline data
      response = client.video.analyze_inline(
        file_path: video_file_path,
        prompt: "Describe this video in detail."
      )

      puts "\n=== Video Description ==="
      if response.valid?
        puts response.text
      else
        puts "Error: #{response.error || 'Unknown error'}"
      end
    else
      puts "Uploading via Files API (20MB or larger)..."
      puts "Waiting for file processing to complete..."

      # Upload large files via Files API
      result = client.video.analyze(
        file_path: video_file_path,
        prompt: "Describe this video in detail."
      )

      puts "\n=== Video Description ==="
      if result[:response].valid?
        puts result[:response].text
      else
        puts "Error: #{result[:response].error || 'Unknown error'}"
      end

      puts "\n=== File Information ==="
      puts "File URI: #{result[:file_uri]}"
      puts "File Name: #{result[:file_name]}"

      # Additional question using uploaded file
      puts "\n=== Additional Question ==="
      question = "List all the people and objects that appear in this video."
      puts "Question: #{question}"
      puts ""

      response = client.video.ask(
        file_uri: result[:file_uri],
        question: question
      )

      if response.valid?
        puts response.text
      else
        puts "Error: #{response.error || 'Unknown error'}"
      end

      # Timestamp extraction example
      puts "\n=== Timestamp Extraction ==="
      query = "important scenes"
      puts "Search: #{query}"
      puts ""

      response = client.video.extract_timestamps(
        file_uri: result[:file_uri],
        query: query
      )

      if response.valid?
        puts response.text
      else
        puts "Error: #{response.error || 'Unknown error'}"
      end

      puts "\nFile will be automatically deleted after 48 hours"
    end
  end

  # End time and elapsed time calculation
  end_time = Time.now
  elapsed_time = end_time - start_time

  puts "\n==============================================="
  puts "Processing time: #{elapsed_time.round(2)} seconds"

rescue StandardError => e
  logger.error "An error occurred: #{e.message}"
  logger.error e.backtrace.join("\n") if ENV["DEBUG"]

  puts "\nDetailed error information:"
  puts "#{e.class}: #{e.message}"

  # API error details
  if defined?(Faraday::Error) && e.is_a?(Faraday::Error)
    puts "API connection error: #{e.message}"
    if e.response
      puts "Response status: #{e.response[:status]}"
      puts "Response body: #{e.response[:body]}"
    end
  end
end
