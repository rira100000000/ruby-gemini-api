#!/usr/bin/env ruby

require 'pathname'
require 'gemini'

def main
  if ARGV.length < 2
    puts "Usage: ruby image_generation_with_multi_image.rb <image1> <image2> [output_file]"
    puts ""
    puts "Examples:"
    puts "  ruby image_generation_with_multi_image.rb cat.png dog.jpg"
    puts "  ruby image_generation_with_multi_image.rb photo1.jpg photo2.png result.png"
    exit 1
  end

  image1_path = ARGV[0]
  image2_path = ARGV[1]
  output_path = ARGV[2] || generate_output_filename(image1_path, image2_path)

  # Verify image files exist
  [image1_path, image2_path].each_with_index do |path, index|
    unless File.exist?(path)
      puts "❌ Image file #{index + 1} '#{path}' not found."
      exit 1
    end
  end

  # Check API key
  api_key = ENV['GEMINI_API_KEY']
  unless api_key
    puts "❌ GEMINI_API_KEY environment variable is not set."
    puts "Please set your Gemini API key:"
    puts "export GEMINI_API_KEY='your_api_key'"
    exit 1
  end

  puts "🎨 Gemini Multi-Image Composition Tool"
  puts "=" * 50
  puts "📷 Image 1: #{File.basename(image1_path)} (#{format_file_size(File.size(image1_path))})"
  puts "📷 Image 2: #{File.basename(image2_path)} (#{format_file_size(File.size(image2_path))})"
  puts "💾 Output: #{File.basename(output_path)}"
  puts ""

  # Get user prompt
  prompt = get_user_prompt

  # Generate image
  puts ""
  puts "🔄 Generating image..."
  puts "   Prompt: \"#{prompt[0..60]}#{prompt.length > 60 ? '...' : ''}\""
  puts "   Please wait..."

  begin
    # Initialize Gemini client
    client = Gemini::Client.new(api_key)
    puts "✅ Gemini client initialized successfully"
    
    # Generate image using client.images.generate
    puts "🚀 Calling API..."
    response = client.images.generate(
      parameters: {
        prompt: prompt,
        image_paths: [image1_path, image2_path],
        model: "gemini-2.5-flash-image-preview",
        temperature: 0.7
      }
    )

    if response.success? && response.images.any?
      puts "✅ Image generation completed!"
      
      # Save image
      saved_file = response.save_image(output_path)
      
      if saved_file
        puts "💾 Generated image saved: #{saved_file}"
        puts "📁 File size: #{format_file_size(File.size(saved_file))}"
        puts ""
        puts "🎉 Generation completed successfully!"
        puts "   Open '#{saved_file}' to view the generated image!"
      else
        puts "❌ Failed to save the generated image"
        exit 1
      end
    else
      puts "❌ Image generation failed"
      if response.error
        puts "   Reason: #{response.error}"
      elsif response.finish_reason
        puts "   Finish reason: #{response.finish_reason}"
      end
      exit 1
    end

  rescue => e
    puts "❌ An error occurred during generation: #{e.message}"
    if ENV['DEBUG']
      puts "Debug information:"
      puts e.backtrace.join("\n")
    end
    exit 1
  end
end

# Get prompt from user
def get_user_prompt
  puts "📝 Please enter a description of the image you want to generate:"
  puts ""
  
  # Display sample prompts
  puts "💡 Example prompts:"
  puts "   - Create an image where these two animals are playing together"
  puts "   - Combine both images into a single artistic composition"
  puts "   - Generate a scene where both subjects interact in a natural setting"
  puts ""
  
  print "👉 Prompt: "
  prompt = STDIN.gets.chomp.strip
  
  # Use default prompt if empty
  if prompt.empty?
    prompt = "Create an artistic composition by combining elements from both input images"
    puts "   Using default prompt: #{prompt}"
  end
  
  puts ""
  
  prompt
end

# Generate output filename
def generate_output_filename(image1_path, image2_path)
  path1 = Pathname.new(image1_path)
  path2 = Pathname.new(image2_path)
  
  # Use the directory of the first image
  dir = path1.dirname
  
  # Combine base names
  basename1 = path1.basename(path1.extname)
  basename2 = path2.basename(path2.extname)
  
  # Add timestamp
  timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
  
  # Save as PNG format
  File.join(dir, "#{basename1}_#{basename2}_combined_#{timestamp}.png")
end

# Format file size in human-readable format
def format_file_size(size)
  units = ['B', 'KB', 'MB', 'GB']
  unit_index = 0
  size_float = size.to_f
  
  while size_float >= 1024 && unit_index < units.length - 1
    size_float /= 1024
    unit_index += 1
  end
  
  if unit_index == 0
    "#{size_float.to_i} #{units[unit_index]}"
  else
    "%.1f #{units[unit_index]}" % size_float
  end
end

# Call main only if script is executed directly
if __FILE__ == $0
  main
end