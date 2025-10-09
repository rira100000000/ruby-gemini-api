module Gemini
  class Images
    def initialize(client:)
      @client = client
    end

    # Main method to generate images
    def generate(parameters: {})
      prompt = parameters[:prompt]
      raise ArgumentError, "prompt parameter is required" unless prompt

      model = parameters[:model] || "gemini-2.5-flash-image-preview"
      
      # Image editing mode if input images are provided (supports single/multiple images)
      if has_input_images?(parameters)
        return generate_with_images(prompt, model, parameters)
      end
      
      # Image generation process based on model
      if model.start_with?("imagen")
        # Use Imagen 3
        response = imagen_generate(prompt, parameters)
      else
        # Use Gemini 2.0
        response = gemini_generate(prompt, parameters)
      end
      
      # Wrap and return response
      Gemini::Response.new(response)
    end
    
    private

    # Check if input images exist (supports single/multiple images)
    def has_input_images?(parameters)
      # Single image parameters
      single_image = parameters[:image] || parameters[:image_path] || parameters[:image_base64]
      # Multiple image parameters
      multiple_images = parameters[:images] || parameters[:image_paths] || parameters[:image_base64s]
      
      single_image || multiple_images
    end
    
    # Image generation with image+text (supports single/multiple images)
    def generate_with_images(prompt, model, parameters)      
      # Process image data (supports single/multiple images)
      image_parts = process_input_images(parameters)
      
      # Build content parts (place text first, then images)
      parts = [{ "text" => prompt }] + image_parts
      
      # Build generation config
      generation_config = {
        "responseModalities" => ["Image"]
      }
      
      # Add temperature setting if provided
      if parameters[:temperature]
        generation_config["temperature"] = parameters[:temperature]
      end
      
      # Build request parameters
      request_params = {
        "contents" => [{
          "parts" => parts
        }],
        "generationConfig" => generation_config
      }
      
      # Merge other parameters (specify keys to exclude)
      excluded_keys = [:prompt, :image, :image_path, :image_base64, :images, :image_paths, :image_base64s, :model, :temperature]
      parameters.each do |key, value|
        next if excluded_keys.include?(key)
        request_params[key.to_s] = value
      end
      
      # API call
      response = @client.json_post(
        path: "models/#{model}:generateContent",
        parameters: request_params
      )
      
      Gemini::Response.new(response)
    end
    
    # Image generation with image+text (kept for backward compatibility)
    def generate_with_image(prompt, model, parameters)
      generate_with_images(prompt, model, parameters)
    end

    # Process input images (supports single/multiple images)
    def process_input_images(parameters)
      image_parts = []
      
      # Process multiple images
      if parameters[:images] || parameters[:image_paths] || parameters[:image_base64s]
        # Multiple file objects
        if parameters[:images]
          parameters[:images].each_with_index do |image, index|
            if image.respond_to?(:read)
              image_data = process_image_io(image)
              image_parts << create_image_part(image_data)
            else
              raise ArgumentError, "Invalid image at index #{index}. Expected file object."
            end
          end
        end
        
        # Multiple file paths
        if parameters[:image_paths]
          parameters[:image_paths].each_with_index do |path, index|
            image_data = process_image_file(path)
            image_parts << create_image_part(image_data)
          end
        end
        
        # Multiple Base64 data
        if parameters[:image_base64s]
          mime_types = parameters[:mime_types] || Array.new(parameters[:image_base64s].size, "image/jpeg")
          parameters[:image_base64s].each_with_index do |base64_data, index|
            image_data = {
              data: base64_data,
              mime_type: mime_types[index] || "image/jpeg"
            }
            image_parts << create_image_part(image_data)
          end
        end
      else
        # Process single image (for backward compatibility)
        image_data = process_single_input_image(parameters)
        image_parts << create_image_part(image_data)
      end
      
      image_parts
    end

    # Process single input image (for backward compatibility)
    def process_single_input_image(parameters)
      if parameters[:image_base64]
        # When Base64 data is provided directly
        {
          data: parameters[:image_base64],
          mime_type: parameters[:mime_type] || "image/jpeg"
        }
      elsif parameters[:image_path]
        # When file path is provided
        process_image_file(parameters[:image_path])
      elsif parameters[:image]
        # When file object is provided
        if parameters[:image].respond_to?(:read)
          process_image_io(parameters[:image])
        else
          raise ArgumentError, "Invalid image parameter. Expected file path, file object, or base64 data."
        end
      else
        raise ArgumentError, "No image data provided"
      end
    end

    # Create API part from image data
    def create_image_part(image_data)
      {
        "inline_data" => {
          "mime_type" => image_data[:mime_type],
          "data" => image_data[:data]
        }
      }
    end

    # Process input image (old method - kept for backward compatibility)
    def process_input_image(parameters)
      process_single_input_image(parameters)
    end

    # Process image from file path (newly added)
    def process_image_file(file_path)
      raise ArgumentError, "File does not exist: #{file_path}" unless File.exist?(file_path)
      
      require 'base64'
      
      # Determine MIME type
      mime_type = determine_image_mime_type(file_path)
      
      # Read file and encode as Base64
      file_data = File.binread(file_path)
      base64_data = Base64.strict_encode64(file_data)
      
      {
        data: base64_data,
        mime_type: mime_type
      }
    end

    # Process image from IO object (newly added)
    def process_image_io(image_io)
      require 'base64'
      
      # Move to beginning of file
      image_io.rewind if image_io.respond_to?(:rewind)
      
      # Read data
      file_data = image_io.read
      
      # Determine MIME type (use file path if available, otherwise infer from content)
      mime_type = if image_io.respond_to?(:path) && image_io.path
                    determine_image_mime_type(image_io.path)
                  else
                    determine_mime_type_from_content(file_data)
                  end
      
      # Base64 encode
      base64_data = Base64.strict_encode64(file_data)
      
      {
        data: base64_data,
        mime_type: mime_type
      }
    end

    # Determine image MIME type from file path (newly added)
    def determine_image_mime_type(file_path)
      ext = File.extname(file_path).downcase
      case ext
      when ".jpg", ".jpeg"
        "image/jpeg"
      when ".png"
        "image/png"
      when ".gif"
        "image/gif"
      when ".webp"
        "image/webp"
      when ".bmp"
        "image/bmp"
      when ".tiff", ".tif"
        "image/tiff"
      else
        # Default to JPEG
        "image/jpeg"
      end
    end

    # Determine MIME type from file content (newly added)
    def determine_mime_type_from_content(data)
      return "image/jpeg" if data.nil? || data.empty?
      
      # Check file header
      header = data[0, 8].bytes
      
      case
      when header[0..1] == [0xFF, 0xD8]
        "image/jpeg"
      when header[0..7] == [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        "image/png"
      when header[0..2] == [0x47, 0x49, 0x46]
        "image/gif"
      when header[0..3] == [0x52, 0x49, 0x46, 0x46] && data[8..11].bytes == [0x57, 0x45, 0x42, 0x50]
        "image/webp"
      when header[0..1] == [0x42, 0x4D]
        "image/bmp"
      else
        # Default to JPEG
        "image/jpeg"
      end
    end

    # Image generation using Gemini 2.0 model (original code unchanged)
    def gemini_generate(prompt, parameters)
      # Prepare parameters
      model = parameters[:model] || "gemini-2.0-flash-exp-image-generation"
      
      # Process size parameter (currently not used in Gemini API)
      # aspect_ratio = process_size_parameter(parameters[:size])
      
      # Build generation config
      generation_config = {
        "responseModalities" => ["Image"]  # Image output only, even for text-only image generation
      }
      
      # Build request parameters
      request_params = {
        "contents" => [{
          "parts" => [
            {"text" => prompt}
          ]
        }],
        "generationConfig" => generation_config
      }
      
      # API call
      @client.json_post(
        path: "models/#{model}:generateContent",
        parameters: request_params
      )
    end
    
    # Image generation using Imagen 3 model (original code unchanged)
    def imagen_generate(prompt, parameters)
      # Get model name (default is Imagen 3 standard model)
      model = parameters[:model] || "imagen-3.0-generate-002"
      
      # Get aspect ratio from size parameter
      aspect_ratio = process_size_parameter(parameters[:size])
      
      # Set number of images to generate
      sample_count = parameters[:n] || parameters[:sample_count] || 1
      sample_count = [[sample_count.to_i, 1].max, 4].min # Limit to range 1-4
      
      # Set person generation setting
      person_generation = parameters[:person_generation] || "ALLOW_ADULT"
      
      # Build request parameters
      request_params = {
        "instances" => [
          {
            "prompt" => prompt
          }
        ],
        "parameters" => {
          "sampleCount" => sample_count
        }
      }
      
      # Add aspect ratio if specified
      request_params["parameters"]["aspectRatio"] = aspect_ratio if aspect_ratio
      
      # Add person generation setting
      request_params["parameters"]["personGeneration"] = person_generation
      
      # API call
      @client.json_post(
        path: "models/#{model}:predict",
        parameters: request_params
      )
    end
    
    # Determine aspect ratio from size parameter (original code unchanged)
    def process_size_parameter(size)
      return nil unless size
      
      case size.to_s
      when "256x256", "512x512", "1024x1024"
        "1:1"
      when "256x384", "512x768", "1024x1536"
        "3:4"
      when "384x256", "768x512", "1536x1024"
        "4:3"
      when "256x448", "512x896", "1024x1792"
        "9:16"
      when "448x256", "896x512", "1792x1024"
        "16:9"
      when "1:1", "3:4", "4:3", "9:16", "16:9"
        size.to_s
      else
        "1:1" # Default
      end
    end
  end
end