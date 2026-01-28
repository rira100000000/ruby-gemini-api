# frozen_string_literal: true

module Gemini
  module FunctionCallingHelper
    # Function Callレスポンスから継続用のcontentsを構築
    # Gemini 3では関数呼び出しの継続時にThought Signatureが必須
    #
    # @param original_contents [Array] 元の会話履歴
    # @param model_response [Gemini::Response] モデルの応答（function call含む）
    # @param function_responses [Array<Hash>] 関数の結果の配列
    #   各要素は { name: "function_name", response: { ... } } の形式
    # @return [Array] 継続リクエスト用のcontents配列
    #
    # @example
    #   contents = Gemini::FunctionCallingHelper.build_continuation(
    #     original_contents: [{ role: "user", parts: [{ text: "東京の天気を教えて" }] }],
    #     model_response: response,
    #     function_responses: [
    #       { name: "get_weather", response: { temperature: 20, condition: "晴れ" } }
    #     ]
    #   )
    def self.build_continuation(original_contents:, model_response:, function_responses:)
      # 元の会話履歴
      contents = original_contents.dup

      # モデルの応答（Signature付き）
      contents << {
        role: "model",
        parts: model_response.build_function_call_parts_with_signature
      }

      # 関数の結果
      function_response_parts = function_responses.map do |fr|
        { functionResponse: fr }
      end

      contents << {
        role: "user",
        parts: function_response_parts
      }

      contents
    end
  end
end
