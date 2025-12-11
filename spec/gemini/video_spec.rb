require 'spec_helper'

RSpec.describe Gemini::Video do
  let(:api_key) { 'test_api_key' }
  let(:client) { instance_double('Gemini::Client') }
  let(:files) { instance_double('Gemini::Files') }
  let(:video) { Gemini::Video.new(client: client) }

  let(:api_response_data) do
    {
      "candidates" => [
        {
          "content" => {
            "parts" => [
              { "text" => "This is a test video analysis result." }
            ]
          }
        }
      ]
    }
  end

  let(:upload_response) do
    {
      "file" => {
        "uri" => "https://generativelanguage.googleapis.com/v1beta/files/video123",
        "name" => "files/video123"
      }
    }
  end

  let(:file_info_active) do
    { "state" => "ACTIVE" }
  end

  before do
    allow(client).to receive(:files).and_return(files)
    allow(client).to receive(:json_post).and_return(api_response_data)
    allow(files).to receive(:upload).and_return(upload_response)
    allow(files).to receive(:get).and_return(file_info_active)
  end

  describe '#analyze' do
    let(:test_video_file) { instance_double('File') }
    let(:file_path) { '/path/to/video.mp4' }

    before do
      allow(test_video_file).to receive(:path).and_return(file_path)
      allow(test_video_file).to receive(:rewind)
      allow(test_video_file).to receive(:read).and_return('Test video data')
      allow(test_video_file).to receive(:close)
      allow(test_video_file).to receive(:size).and_return(1024)
      allow(File).to receive(:extname).with(file_path).and_return('.mp4')
      allow(File).to receive(:open).with(file_path, "rb").and_return(test_video_file)
    end

    context 'basic analysis with file object' do
      it 'uploads file and sends API request' do
        result = video.analyze(file: test_video_file, prompt: "Describe this video")

        expect(files).to have_received(:upload).with(file: test_video_file)
        expect(client).to have_received(:json_post) do |args|
          expect(args[:path]).to include(":generateContent")
          contents = args[:parameters][:contents]
          expect(contents[0][:parts][0][:text]).to eq("Describe this video")
          expect(contents[0][:parts][1][:file_data][:file_uri]).to eq(upload_response["file"]["uri"])
        end
      end

      it 'returns result with response and file info' do
        result = video.analyze(file: test_video_file, prompt: "Describe this video")

        expect(result[:response]).to be_a(Gemini::Response)
        expect(result[:file_uri]).to eq(upload_response["file"]["uri"])
        expect(result[:file_name]).to eq(upload_response["file"]["name"])
      end
    end

    context 'analysis with file_path' do
      it 'opens file and processes correctly' do
        result = video.analyze(file_path: file_path, prompt: "Describe this video")

        expect(File).to have_received(:open).with(file_path, "rb")
        expect(result[:response]).to be_a(Gemini::Response)
      end
    end

    context 'with custom model' do
      it 'uses the specified model' do
        custom_model = "gemini-2.0-pro"
        video.analyze(file: test_video_file, prompt: "Describe", model: custom_model)

        expect(client).to have_received(:json_post) do |args|
          expect(args[:path]).to eq("models/#{custom_model}:generateContent")
        end
      end
    end

    context 'without file' do
      it 'raises ArgumentError' do
        expect {
          video.analyze(prompt: "Describe this video")
        }.to raise_error(ArgumentError, "file or file_path parameter is required")
      end
    end
  end

  describe '#analyze_with_file_uri' do
    let(:file_uri) { "https://generativelanguage.googleapis.com/v1beta/files/video123" }

    it 'sends API request with file_uri' do
      result = video.analyze_with_file_uri(file_uri: file_uri, prompt: "Describe this video")

      expect(client).to have_received(:json_post) do |args|
        contents = args[:parameters][:contents]
        expect(contents[0][:parts][1][:file_data][:file_uri]).to eq(file_uri)
      end
      expect(result).to be_a(Gemini::Response)
    end

    it 'uses custom mime_type when specified' do
      video.analyze_with_file_uri(file_uri: file_uri, prompt: "Describe", mime_type: "video/webm")

      expect(client).to have_received(:json_post) do |args|
        file_data = args[:parameters][:contents][0][:parts][1][:file_data]
        expect(file_data[:mime_type]).to eq("video/webm")
      end
    end
  end

  describe '#analyze_youtube' do
    let(:youtube_url) { "https://www.youtube.com/watch?v=dQw4w9WgXcQ" }

    it 'sends API request with YouTube URL' do
      result = video.analyze_youtube(url: youtube_url, prompt: "Describe this video")

      expect(client).to have_received(:json_post) do |args|
        contents = args[:parameters][:contents]
        expect(contents[0][:parts][1][:file_data][:file_uri]).to eq(youtube_url)
      end
      expect(result).to be_a(Gemini::Response)
    end

    context 'with various YouTube URL formats' do
      [
        "https://www.youtube.com/watch?v=abc123",
        "https://youtube.com/watch?v=abc123",
        "https://youtu.be/abc123",
        "https://www.youtube.com/embed/abc123",
        "https://www.youtube.com/v/abc123",
        "https://www.youtube.com/shorts/abc123"
      ].each do |url|
        it "accepts #{url}" do
          expect {
            video.analyze_youtube(url: url, prompt: "Describe")
          }.not_to raise_error
        end
      end
    end

    context 'with invalid YouTube URL' do
      it 'raises ArgumentError' do
        expect {
          video.analyze_youtube(url: "https://vimeo.com/12345", prompt: "Describe")
        }.to raise_error(ArgumentError, /Invalid YouTube URL/)
      end
    end
  end

  describe '#analyze_inline' do
    let(:test_video_file) { instance_double('File') }
    let(:file_path) { '/path/to/small_video.mp4' }
    let(:small_file_size) { 10 * 1024 * 1024 } # 10MB

    before do
      allow(test_video_file).to receive(:path).and_return(file_path)
      allow(test_video_file).to receive(:rewind)
      allow(test_video_file).to receive(:read).and_return('Test video data')
      allow(test_video_file).to receive(:close)
      allow(test_video_file).to receive(:size).and_return(small_file_size)
      allow(File).to receive(:extname).with(file_path).and_return('.mp4')
      allow(File).to receive(:open).with(file_path, "rb").and_return(test_video_file)
      require 'base64'
      allow(Base64).to receive(:strict_encode64).and_return('encoded_video_data')
    end

    it 'sends inline data request' do
      result = video.analyze_inline(file: test_video_file, prompt: "Describe this video")

      expect(client).to have_received(:json_post) do |args|
        contents = args[:parameters][:contents]
        expect(contents[0][:parts][1][:inline_data]).not_to be_nil
        expect(contents[0][:parts][1][:inline_data][:data]).to eq('encoded_video_data')
      end
      expect(result).to be_a(Gemini::Response)
    end

    context 'with file larger than 20MB' do
      let(:large_file_size) { 25 * 1024 * 1024 } # 25MB

      before do
        allow(test_video_file).to receive(:size).and_return(large_file_size)
      end

      it 'raises ArgumentError' do
        expect {
          video.analyze_inline(file: test_video_file, prompt: "Describe")
        }.to raise_error(ArgumentError, /File size exceeds 20MB/)
      end
    end
  end

  describe '#describe' do
    let(:test_video_file) { instance_double('File') }
    let(:file_path) { '/path/to/video.mp4' }

    before do
      allow(test_video_file).to receive(:path).and_return(file_path)
      allow(test_video_file).to receive(:rewind)
      allow(test_video_file).to receive(:read).and_return('Test video data')
      allow(test_video_file).to receive(:close)
      allow(test_video_file).to receive(:size).and_return(1024)
      allow(File).to receive(:extname).with(file_path).and_return('.mp4')
      allow(File).to receive(:open).with(file_path, "rb").and_return(test_video_file)
    end

    it 'uses Japanese prompt by default' do
      video.describe(file: test_video_file)

      expect(client).to have_received(:json_post) do |args|
        text = args[:parameters][:contents][0][:parts][0][:text]
        expect(text).to include("この動画の内容を詳しく説明してください")
      end
    end

    it 'uses English prompt when language is en' do
      video.describe(file: test_video_file, language: "en")

      expect(client).to have_received(:json_post) do |args|
        text = args[:parameters][:contents][0][:parts][0][:text]
        expect(text).to eq("Describe this video in detail.")
      end
    end

    context 'with youtube_url' do
      it 'calls analyze_youtube' do
        youtube_url = "https://www.youtube.com/watch?v=abc123"
        result = video.describe(youtube_url: youtube_url)

        expect(result).to be_a(Gemini::Response)
      end
    end

    context 'with file_uri' do
      it 'calls analyze_with_file_uri' do
        file_uri = "files/video123"
        result = video.describe(file_uri: file_uri)

        expect(result).to be_a(Gemini::Response)
      end
    end

    context 'without any input' do
      it 'raises ArgumentError' do
        expect {
          video.describe
        }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#extract_timestamps' do
    let(:file_uri) { "files/video123" }

    it 'sends timestamp extraction request' do
      video.extract_timestamps(file_uri: file_uri, query: "登場人物")

      expect(client).to have_received(:json_post) do |args|
        text = args[:parameters][:contents][0][:parts][0][:text]
        expect(text).to include("登場人物")
        expect(text).to include("タイムスタンプ")
      end
    end
  end

  describe '#analyze_segment' do
    let(:file_uri) { "files/video123" }

    it 'includes video_metadata with offsets' do
      video.analyze_segment(
        file_uri: file_uri,
        prompt: "Describe this segment",
        start_offset: "10s",
        end_offset: "30s"
      )

      expect(client).to have_received(:json_post) do |args|
        file_data = args[:parameters][:contents][0][:parts][1][:file_data]
        expect(file_data[:video_metadata][:startOffset]).to eq("10s")
        expect(file_data[:video_metadata][:endOffset]).to eq("30s")
      end
    end

    it 'omits video_metadata when no offsets specified' do
      video.analyze_segment(file_uri: file_uri, prompt: "Describe")

      expect(client).to have_received(:json_post) do |args|
        file_data = args[:parameters][:contents][0][:parts][1][:file_data]
        expect(file_data[:video_metadata]).to be_nil
      end
    end
  end

  describe '#ask' do
    let(:file_uri) { "files/video123" }

    it 'sends question to the API' do
      question = "What is happening in this video?"
      video.ask(file_uri: file_uri, question: question)

      expect(client).to have_received(:json_post) do |args|
        text = args[:parameters][:contents][0][:parts][0][:text]
        expect(text).to eq(question)
      end
    end
  end

  describe 'file state waiting' do
    let(:test_video_file) { instance_double('File') }
    let(:file_path) { '/path/to/video.mp4' }

    before do
      allow(test_video_file).to receive(:path).and_return(file_path)
      allow(test_video_file).to receive(:rewind)
      allow(test_video_file).to receive(:read).and_return('Test video data')
      allow(test_video_file).to receive(:close)
      allow(test_video_file).to receive(:size).and_return(1024)
      allow(File).to receive(:extname).with(file_path).and_return('.mp4')
      allow(File).to receive(:open).with(file_path, "rb").and_return(test_video_file)
    end

    context 'when file is initially PROCESSING then becomes ACTIVE' do
      before do
        call_count = 0
        allow(files).to receive(:get) do
          call_count += 1
          if call_count < 3
            { "state" => "PROCESSING" }
          else
            { "state" => "ACTIVE" }
          end
        end
        allow(video).to receive(:sleep) # Mock sleep to speed up test
      end

      it 'waits for file to become ACTIVE' do
        result = video.analyze(file: test_video_file, prompt: "Describe")
        expect(files).to have_received(:get).at_least(3).times
        expect(result[:response]).to be_a(Gemini::Response)
      end
    end

    context 'when file processing fails' do
      before do
        allow(files).to receive(:get).and_return({
          "state" => "FAILED",
          "error" => { "message" => "Processing error" }
        })
      end

      it 'raises error' do
        expect {
          video.analyze(file: test_video_file, prompt: "Describe")
        }.to raise_error(StandardError, /File processing failed/)
      end
    end
  end

  describe 'MIME type detection' do
    let(:test_video_file) { instance_double('File') }

    before do
      allow(test_video_file).to receive(:rewind)
      allow(test_video_file).to receive(:read).and_return('Test video data')
      allow(test_video_file).to receive(:close)
      allow(test_video_file).to receive(:size).and_return(1024)
    end

    {
      '.mp4' => 'video/mp4',
      '.mpeg' => 'video/mpeg',
      '.mpg' => 'video/mpeg',
      '.mov' => 'video/quicktime',
      '.avi' => 'video/x-msvideo',
      '.flv' => 'video/x-flv',
      '.webm' => 'video/webm',
      '.wmv' => 'video/x-ms-wmv',
      '.3gp' => 'video/3gpp',
      '.3gpp' => 'video/3gpp',
      '.unknown' => 'video/mp4' # Default
    }.each do |ext, expected_mime|
      it "detects #{expected_mime} for #{ext} files" do
        file_path = "/path/to/video#{ext}"
        allow(test_video_file).to receive(:path).and_return(file_path)
        allow(File).to receive(:extname).with(file_path).and_return(ext)
        allow(File).to receive(:open).with(file_path, "rb").and_return(test_video_file)

        video.analyze(file_path: file_path, prompt: "Describe")

        expect(client).to have_received(:json_post) do |args|
          mime_type = args[:parameters][:contents][0][:parts][1][:file_data][:mime_type]
          expect(mime_type).to eq(expected_mime)
        end
      end
    end
  end
end
