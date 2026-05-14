module Gemini
  class Tokens
    DEFAULT_MODEL = "gemini-2.5-flash".freeze

    def initialize(client:)
      @client = client
    end

    # Count tokens for the given input.
    #
    # input: String, Array of parts/contents, or Hash. Optional when `contents:` is given.
    # contents: full Array of Content objects (overrides input).
    # system_instruction: String or Content hash.
    # tools: Array of tool definitions (passed via generateContentRequest form).
    # generation_config: Hash forwarded as generationConfig.
    # cached_content: cachedContents/* resource name.
    def count(input = nil, model: DEFAULT_MODEL, contents: nil, system_instruction: nil,
              tools: nil, generation_config: nil, cached_content: nil, **parameters)
      normalized_model = normalize_model(model)

      payload = build_payload(
        model: normalized_model,
        input: input,
        contents: contents,
        system_instruction: system_instruction,
        tools: tools,
        generation_config: generation_config,
        cached_content: cached_content
      ).merge(parameters)

      response = @client.json_post(
        path: "models/#{normalized_model}:countTokens",
        parameters: payload
      )
      Gemini::Response.new(response)
    end

    private

    def build_payload(model:, input:, contents:, system_instruction:, tools:, generation_config:, cached_content:)
      resolved_contents = contents || [format_content(input)]

      # Use generateContentRequest form when extra request fields are present
      if system_instruction || tools || generation_config || cached_content
        # model is required inside the nested GenerateContentRequest
        gc_request = { model: "models/#{model}", contents: resolved_contents }
        gc_request[:systemInstruction] = format_content(system_instruction) if system_instruction
        gc_request[:tools] = tools if tools
        gc_request[:generationConfig] = generation_config if generation_config
        gc_request[:cachedContent] = cached_content if cached_content
        { generateContentRequest: gc_request }
      else
        { contents: resolved_contents }
      end
    end

    def format_content(input)
      case input
      when nil
        raise ArgumentError, "input or contents parameter is required"
      when String
        { parts: [{ text: input }] }
      when Array
        { parts: input.map { |part| part.is_a?(String) ? { text: part } : part } }
      when Hash
        input.key?(:parts) || input.key?("parts") ? input : { parts: [input] }
      else
        { parts: [{ text: input.to_s }] }
      end
    end

    def normalize_model(model)
      model_str = model.to_s
      model_str.start_with?("models/") ? model_str.delete_prefix("models/") : model_str
    end
  end
end
