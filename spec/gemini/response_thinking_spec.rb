require 'spec_helper'

RSpec.describe Gemini::Response do
  # Mock of a response with thinking metadata
  let(:thinking_response_data) do
    {
      'candidates' => [
        {
          'content' => {
            'parts' => [
              { 'text' => 'This is a thought-out response.' }
            ],
            'role' => 'model'
          },
          'finishReason' => 'STOP'
        }
      ],
      'usageMetadata' => {
        'promptTokenCount' => 100,
        'candidatesTokenCount' => 50,
        'totalTokenCount' => 300,
        'thoughtsTokenCount' => 150
      },
      'modelVersion' => 'gemini-2.5-flash'
    }
  end

  # Mock of a function call response with thought signature
  let(:function_call_with_signature_data) do
    {
      'candidates' => [
        {
          'content' => {
            'parts' => [
              {
                'functionCall' => {
                  'name' => 'get_weather',
                  'args' => { 'location' => 'Tokyo' }
                },
                'thoughtSignature' => 'base64encoded_signature_123'
              }
            ],
            'role' => 'model'
          },
          'finishReason' => 'STOP'
        }
      ],
      'usageMetadata' => {
        'thoughtsTokenCount' => 120
      },
      'modelVersion' => 'gemini-3-flash-preview'
    }
  end

  # Mock of multiple function calls with signature
  let(:multiple_function_calls_data) do
    {
      'candidates' => [
        {
          'content' => {
            'parts' => [
              {
                'functionCall' => {
                  'name' => 'get_weather',
                  'args' => { 'location' => 'Tokyo' }
                },
                'thoughtSignature' => 'signature_abc123'
              },
              {
                'functionCall' => {
                  'name' => 'get_time',
                  'args' => { 'timezone' => 'Asia/Tokyo' }
                }
              }
            ],
            'role' => 'model'
          },
          'finishReason' => 'STOP'
        }
      ],
      'modelVersion' => 'gemini-3-flash-preview'
    }
  end

  # Mock without thinking metadata
  let(:no_thinking_response_data) do
    {
      'candidates' => [
        {
          'content' => {
            'parts' => [
              { 'text' => 'Regular response without thinking.' }
            ],
            'role' => 'model'
          },
          'finishReason' => 'STOP'
        }
      ],
      'usageMetadata' => {
        'promptTokenCount' => 10,
        'candidatesTokenCount' => 20,
        'totalTokenCount' => 30
      },
      'modelVersion' => 'gemini-2.0-flash'
    }
  end

  describe '#thoughts_token_count' do
    it 'returns thoughts token count from usage metadata' do
      response = described_class.new(thinking_response_data)
      expect(response.thoughts_token_count).to eq(150)
    end

    it 'returns nil when thoughts token count is not present' do
      response = described_class.new(no_thinking_response_data)
      expect(response.thoughts_token_count).to be_nil
    end

    it 'returns nil for empty response' do
      response = described_class.new({})
      expect(response.thoughts_token_count).to be_nil
    end
  end

  describe '#thought_signatures' do
    it 'extracts signatures from parts' do
      response = described_class.new(function_call_with_signature_data)
      expect(response.thought_signatures).to eq(['base64encoded_signature_123'])
    end

    it 'returns empty array when no signatures present' do
      response = described_class.new(thinking_response_data)
      expect(response.thought_signatures).to eq([])
    end

    it 'extracts multiple signatures if present' do
      multi_sig_data = {
        'candidates' => [
          {
            'content' => {
              'parts' => [
                { 'functionCall' => {}, 'thoughtSignature' => 'sig1' },
                { 'functionCall' => {}, 'thoughtSignature' => 'sig2' }
              ]
            }
          }
        ]
      }
      response = described_class.new(multi_sig_data)
      expect(response.thought_signatures).to eq(['sig1', 'sig2'])
    end
  end

  describe '#first_thought_signature' do
    it 'returns the first signature' do
      response = described_class.new(function_call_with_signature_data)
      expect(response.first_thought_signature).to eq('base64encoded_signature_123')
    end

    it 'returns nil when no signatures present' do
      response = described_class.new(thinking_response_data)
      expect(response.first_thought_signature).to be_nil
    end
  end

  describe '#has_thought_signature?' do
    it 'returns true when signature is present' do
      response = described_class.new(function_call_with_signature_data)
      expect(response.has_thought_signature?).to be true
    end

    it 'returns false when no signature present' do
      response = described_class.new(thinking_response_data)
      expect(response.has_thought_signature?).to be false
    end
  end

  describe '#model_version' do
    it 'returns the model version' do
      response = described_class.new(thinking_response_data)
      expect(response.model_version).to eq('gemini-2.5-flash')
    end

    it 'returns nil when model version is not present' do
      response = described_class.new({ 'candidates' => [] })
      expect(response.model_version).to be_nil
    end
  end

  describe '#gemini_3?' do
    it 'returns true for gemini-3 models' do
      response = described_class.new(function_call_with_signature_data)
      expect(response.gemini_3?).to be true
    end

    it 'returns false for gemini-2 models' do
      response = described_class.new(thinking_response_data)
      expect(response.gemini_3?).to be false
    end

    it 'returns false when model version is not present' do
      response = described_class.new({ 'candidates' => [] })
      expect(response.gemini_3?).to be false
    end
  end

  describe '#build_function_call_parts_with_signature' do
    it 'attaches signature to first function call part' do
      response = described_class.new(function_call_with_signature_data)
      parts = response.build_function_call_parts_with_signature

      expect(parts.size).to eq(1)
      expect(parts[0][:functionCall]).to eq({ 'name' => 'get_weather', 'args' => { 'location' => 'Tokyo' } })
      expect(parts[0][:thoughtSignature]).to eq('base64encoded_signature_123')
    end

    it 'attaches signature only to first function call when multiple calls exist' do
      response = described_class.new(multiple_function_calls_data)
      parts = response.build_function_call_parts_with_signature

      expect(parts.size).to eq(2)
      expect(parts[0][:thoughtSignature]).to eq('signature_abc123')
      expect(parts[1]).not_to have_key(:thoughtSignature)
    end

    it 'returns parts without signature when no signature present' do
      data = {
        'candidates' => [
          {
            'content' => {
              'parts' => [
                { 'functionCall' => { 'name' => 'test', 'args' => {} } }
              ]
            }
          }
        ]
      }
      response = described_class.new(data)
      parts = response.build_function_call_parts_with_signature

      expect(parts.size).to eq(1)
      expect(parts[0]).not_to have_key(:thoughtSignature)
    end

    it 'returns empty array when no function calls present' do
      response = described_class.new(thinking_response_data)
      parts = response.build_function_call_parts_with_signature

      expect(parts).to eq([])
    end
  end
end

RSpec.describe Gemini::FunctionCallingHelper do
  describe '.build_continuation' do
    let(:original_contents) do
      [
        { role: 'user', parts: [{ text: 'What is the weather in Tokyo?' }] }
      ]
    end

    let(:model_response_data) do
      {
        'candidates' => [
          {
            'content' => {
              'parts' => [
                {
                  'functionCall' => {
                    'name' => 'get_weather',
                    'args' => { 'location' => 'Tokyo' }
                  },
                  'thoughtSignature' => 'test_signature_xyz'
                }
              ],
              'role' => 'model'
            }
          }
        ]
      }
    end

    let(:function_responses) do
      [
        { name: 'get_weather', response: { temperature: 20, condition: 'sunny' } }
      ]
    end

    it 'builds continuation contents with signature' do
      model_response = Gemini::Response.new(model_response_data)

      contents = described_class.build_continuation(
        original_contents: original_contents,
        model_response: model_response,
        function_responses: function_responses
      )

      expect(contents.size).to eq(3)

      # Original user message
      expect(contents[0]).to eq(original_contents[0])

      # Model response with signature
      expect(contents[1][:role]).to eq('model')
      expect(contents[1][:parts][0][:functionCall]).to eq({
        'name' => 'get_weather',
        'args' => { 'location' => 'Tokyo' }
      })
      expect(contents[1][:parts][0][:thoughtSignature]).to eq('test_signature_xyz')

      # Function response
      expect(contents[2][:role]).to eq('user')
      expect(contents[2][:parts][0][:functionResponse]).to eq(function_responses[0])
    end

    it 'handles multiple function responses' do
      multi_fc_data = {
        'candidates' => [
          {
            'content' => {
              'parts' => [
                {
                  'functionCall' => { 'name' => 'fn1', 'args' => {} },
                  'thoughtSignature' => 'sig'
                },
                {
                  'functionCall' => { 'name' => 'fn2', 'args' => {} }
                }
              ]
            }
          }
        ]
      }
      model_response = Gemini::Response.new(multi_fc_data)

      multi_responses = [
        { name: 'fn1', response: { result: 'a' } },
        { name: 'fn2', response: { result: 'b' } }
      ]

      contents = described_class.build_continuation(
        original_contents: original_contents,
        model_response: model_response,
        function_responses: multi_responses
      )

      expect(contents[2][:parts].size).to eq(2)
    end

    it 'works without thought signature' do
      no_sig_data = {
        'candidates' => [
          {
            'content' => {
              'parts' => [
                { 'functionCall' => { 'name' => 'test', 'args' => {} } }
              ]
            }
          }
        ]
      }
      model_response = Gemini::Response.new(no_sig_data)

      contents = described_class.build_continuation(
        original_contents: original_contents,
        model_response: model_response,
        function_responses: [{ name: 'test', response: {} }]
      )

      expect(contents[1][:parts][0]).not_to have_key(:thoughtSignature)
    end
  end
end
