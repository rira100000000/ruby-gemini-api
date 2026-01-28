require 'spec_helper'

RSpec.describe Gemini::Client do
  let(:api_key) { ENV['GEMINI_API_KEY'] || 'test_api_key' }
  let(:client) { described_class.new(api_key) }

  describe '#build_thinking_config' do
    context 'thinking_budget' do
      it 'accepts positive integer' do
        config = client.send(:build_thinking_config, 2048, nil)
        expect(config).to eq({ thinkingBudget: 2048 })
      end

      it 'accepts -1 for dynamic thinking' do
        config = client.send(:build_thinking_config, -1, nil)
        expect(config).to eq({ thinkingBudget: -1 })
      end

      it 'accepts 0 to disable thinking' do
        config = client.send(:build_thinking_config, 0, nil)
        expect(config).to eq({ thinkingBudget: 0 })
      end

      it 'accepts maximum value of 32768' do
        config = client.send(:build_thinking_config, 32768, nil)
        expect(config).to eq({ thinkingBudget: 32768 })
      end

      it 'raises error for budget exceeding maximum' do
        expect { client.send(:build_thinking_config, 50000, nil) }
          .to raise_error(ArgumentError, /thinking_budget must be -1, 0, or 1-32768/)
      end

      it 'raises error for negative budget other than -1' do
        expect { client.send(:build_thinking_config, -2, nil) }
          .to raise_error(ArgumentError, /thinking_budget must be -1, 0, or 1-32768/)
      end

      it 'raises error for non-integer budget' do
        expect { client.send(:build_thinking_config, 1.5, nil) }
          .to raise_error(ArgumentError, /thinking_budget must be -1, 0, or 1-32768/)
      end
    end

    context 'thinking_level' do
      %i[minimal low medium high].each do |level|
        it "accepts #{level} as symbol" do
          config = client.send(:build_thinking_config, nil, level)
          expect(config).to eq({ thinkingLevel: level.to_s })
        end
      end

      %w[minimal low medium high].each do |level|
        it "accepts #{level} as string" do
          config = client.send(:build_thinking_config, nil, level)
          expect(config).to eq({ thinkingLevel: level })
        end
      end

      it 'raises error for invalid level' do
        expect { client.send(:build_thinking_config, nil, :invalid) }
          .to raise_error(ArgumentError, /thinking_level must be one of: minimal, low, medium, high/)
      end

      it 'raises error for invalid string level' do
        expect { client.send(:build_thinking_config, nil, 'extreme') }
          .to raise_error(ArgumentError, /thinking_level must be one of: minimal, low, medium, high/)
      end
    end

    context 'both parameters' do
      it 'includes both when both are provided' do
        config = client.send(:build_thinking_config, 2048, :high)
        expect(config).to eq({ thinkingBudget: 2048, thinkingLevel: 'high' })
      end
    end

    context 'without thinking options' do
      it 'returns nil when both are nil' do
        config = client.send(:build_thinking_config, nil, nil)
        expect(config).to be_nil
      end
    end
  end

  describe '#generate_content with thinking options' do
    let(:response_body) do
      {
        'candidates' => [
          {
            'content' => {
              'parts' => [{ 'text' => 'Test response' }],
              'role' => 'model'
            },
            'finishReason' => 'STOP'
          }
        ],
        'usageMetadata' => {
          'thoughtsTokenCount' => 150
        }
      }
    end

    let(:response_instance) { instance_double(Gemini::Response) }

    before do
      allow(Gemini::Response).to receive(:new).and_return(response_instance)
      allow(response_instance).to receive(:text).and_return('Test response')
    end

    context 'with thinking_budget' do
      it 'includes thinkingConfig in request' do
        stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=#{api_key}")
          .with(
            body: hash_including(
              'generation_config' => hash_including(
                'thinkingConfig' => { 'thinkingBudget' => 2048 }
              )
            )
          )
          .to_return(status: 200, body: response_body.to_json, headers: { 'Content-Type' => 'application/json' })

        client.generate_content('Test prompt', thinking_budget: 2048)
      end
    end

    context 'with thinking_level' do
      it 'includes thinkingConfig in request' do
        stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent?key=#{api_key}")
          .with(
            body: hash_including(
              'generation_config' => hash_including(
                'thinkingConfig' => { 'thinkingLevel' => 'high' }
              )
            )
          )
          .to_return(status: 200, body: response_body.to_json, headers: { 'Content-Type' => 'application/json' })

        client.generate_content('Test prompt', model: 'gemini-3-flash-preview', thinking_level: :high)
      end
    end
  end

  describe '#chat with thinking options' do
    let(:response_body) do
      {
        'candidates' => [
          {
            'content' => {
              'parts' => [{ 'text' => 'Chat response' }],
              'role' => 'model'
            },
            'finishReason' => 'STOP'
          }
        ]
      }
    end

    let(:response_instance) { instance_double(Gemini::Response) }

    before do
      allow(Gemini::Response).to receive(:new).and_return(response_instance)
      allow(response_instance).to receive(:text).and_return('Chat response')
    end

    it 'includes thinkingConfig when thinking_budget is provided in parameters' do
      stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=#{api_key}")
        .with(
          body: hash_including(
            'generationConfig' => hash_including(
              'thinkingConfig' => { 'thinkingBudget' => 1024 }
            )
          )
        )
        .to_return(status: 200, body: response_body.to_json, headers: { 'Content-Type' => 'application/json' })

      client.chat(parameters: {
        contents: [{ parts: [{ text: 'Hi' }] }],
        thinking_budget: 1024
      })
    end

    it 'includes thinkingConfig when thinking_level is provided in parameters' do
      stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=#{api_key}")
        .with(
          body: hash_including(
            'generationConfig' => hash_including(
              'thinkingConfig' => { 'thinkingLevel' => 'medium' }
            )
          )
        )
        .to_return(status: 200, body: response_body.to_json, headers: { 'Content-Type' => 'application/json' })

      client.chat(parameters: {
        contents: [{ parts: [{ text: 'Hi' }] }],
        thinking_level: :medium
      })
    end
  end
end
