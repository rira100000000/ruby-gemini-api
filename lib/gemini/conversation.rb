module Gemini
  class Conversation
    attr_reader :client, :model, :history, :thinking_config, :system_instruction

    def initialize(client:, model: "gemini-2.5-flash", system_instruction: nil, thinking_config: nil)
      @client = client
      @model = model
      @system_instruction = system_instruction
      @thinking_config = thinking_config
      @history = []
    end

    # Send a message and maintain conversation history with thought signatures
    def send_message(content, **options)
      # Prepare request contents (history + new user message)
      contents = prepare_contents(content)

      # Build request parameters
      params = {
        contents: contents,
        model: @model
      }

      # Add system instruction if provided
      if @system_instruction
        params[:system_instruction] = @client.send(:format_content, @system_instruction)
      end

      # Add thinking_config if provided (must be inside generationConfig for REST API)
      if @thinking_config
        normalized_config = @client.send(:normalize_thinking_config, @thinking_config)
        if normalized_config
          params[:generation_config] ||= {}
          params[:generation_config]["thinkingConfig"] = normalized_config
        end
      end

      # Merge any additional options
      params.merge!(options)

      # Send request via client's chat method
      response = @client.chat(parameters: params)

      # Add user message to history
      @history << {
        "role" => "user",
        "parts" => normalize_parts(content)
      }

      # Add model response to history (with signatures if present)
      if response.valid?
        @history << response.content_for_history
      end

      response
    end

    # Clear conversation history
    def clear_history
      @history = []
    end

    # Get conversation history (returns a copy to prevent external modification)
    def get_history
      @history.dup
    end

    private

    # Prepare contents array (history + new user message)
    def prepare_contents(new_content)
      # Convert history + new message to contents array
      history_contents = @history.dup

      user_message = {
        "role" => "user",
        "parts" => normalize_parts(new_content)
      }

      history_contents + [user_message]
    end

    # Normalize content input to parts array format
    def normalize_parts(content)
      case content
      when String
        [{ "text" => content }]
      when Array
        # If array of hashes, use as-is; if array of strings, convert
        content.map do |item|
          if item.is_a?(Hash)
            item
          else
            { "text" => item.to_s }
          end
        end
      when Hash
        # If it has a :parts key, use that; otherwise wrap in array
        if content.key?(:parts) || content.key?("parts")
          content[:parts] || content["parts"]
        else
          [content]
        end
      else
        [{ "text" => content.to_s }]
      end
    end
  end
end
