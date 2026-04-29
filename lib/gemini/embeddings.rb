module Gemini
  class Embeddings
    DEFAULT_MODEL = "gemini-embedding-001".freeze

    VALID_TASK_TYPES = %w[
      RETRIEVAL_QUERY
      RETRIEVAL_DOCUMENT
      SEMANTIC_SIMILARITY
      CLASSIFICATION
      CLUSTERING
      QUESTION_ANSWERING
      FACT_VERIFICATION
      CODE_RETRIEVAL_QUERY
    ].freeze

    def initialize(client:)
      @client = client
    end

    # Generate an embedding for a single content, or batch when input is an Array
    def create(input:, model: DEFAULT_MODEL, task_type: nil, title: nil,
               output_dimensionality: nil, **parameters)
      if input.is_a?(Array)
        return batch_create(
          inputs: input,
          model: model,
          task_type: task_type,
          title: title,
          output_dimensionality: output_dimensionality,
          **parameters
        )
      end

      payload = build_embed_payload(
        input: input,
        task_type: task_type,
        title: title,
        output_dimensionality: output_dimensionality
      ).merge(parameters)

      response = @client.json_post(
        path: "models/#{normalize_model(model)}:embedContent",
        parameters: payload
      )
      Gemini::Response.new(response)
    end

    # Generate embeddings for multiple inputs in a single batch request
    def batch_create(inputs:, model: DEFAULT_MODEL, task_type: nil, title: nil,
                     output_dimensionality: nil, **parameters)
      requests = inputs.map do |input|
        req = build_embed_payload(
          input: input,
          task_type: task_type,
          title: title,
          output_dimensionality: output_dimensionality
        )
        req[:model] = "models/#{normalize_model(model)}"
        req
      end

      payload = { requests: requests }.merge(parameters)

      response = @client.json_post(
        path: "models/#{normalize_model(model)}:batchEmbedContents",
        parameters: payload
      )
      Gemini::Response.new(response)
    end

    private

    def build_embed_payload(input:, task_type:, title:, output_dimensionality:)
      payload = { content: format_content(input) }

      if task_type
        validate_task_type!(task_type)
        payload[:taskType] = task_type.to_s.upcase
      end

      payload[:title] = title if title
      payload[:outputDimensionality] = output_dimensionality if output_dimensionality

      payload
    end

    def format_content(input)
      case input
      when String
        { parts: [{ text: input }] }
      when Hash
        if input.key?(:parts) || input.key?("parts")
          input
        elsif input.key?(:text) || input.key?("text") ||
              input.key?(:inline_data) || input.key?("inline_data") ||
              input.key?(:file_data) || input.key?("file_data")
          { parts: [input] }
        else
          input
        end
      else
        { parts: [{ text: input.to_s }] }
      end
    end

    def normalize_model(model)
      model_str = model.to_s
      model_str.start_with?("models/") ? model_str.delete_prefix("models/") : model_str
    end

    def validate_task_type!(task_type)
      task_type_str = task_type.to_s.upcase
      unless VALID_TASK_TYPES.include?(task_type_str)
        raise ArgumentError, "task_type must be one of: #{VALID_TASK_TYPES.join(', ')}"
      end
    end
  end
end
