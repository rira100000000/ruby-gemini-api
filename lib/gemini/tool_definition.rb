module Gemini
  class ToolDefinition
    def initialize(&block)
      @functions = {}
      instance_eval(&block) if block_given?
    end

    def function(name, description:, &block)
      @functions[name] = {
        name: name,
        description: description,
        parameters: {
          type: 'object',
          properties: {},
          required: []
        }
      }
      @current_function = name
      instance_eval(&block) if block_given?
      @current_function = nil
    end
    alias add_function function

    def property(name, type:, description:, required: false)
      raise 'property must be defined within a function block' unless @current_function

      @functions[@current_function][:parameters][:properties][name] = {
        type: type.to_s,
        description: description
      }
      @functions[@current_function][:parameters][:required] << name if required
    end

    def +(other)
      raise ArgumentError, 'can only merge with another ToolDefinition' unless other.is_a?(ToolDefinition)

      new_definition = dup
      other.instance_variable_get(:@functions).each do |name, definition|
        new_definition.instance_variable_get(:@functions)[name] = definition
      end
      new_definition
    end

    def delete_function(name)
      @functions.delete(name)
    end

    def list_functions
      @functions.keys
    end

    def to_h
      {
        function_declarations: @functions.values
      }
    end

    def to_json(*args)
      to_h.to_json(*args)
    end

    def dup
      new_instance = self.class.new
      new_instance.instance_variable_set(:@functions, @functions.dup)
      new_instance
    end
  end
end
