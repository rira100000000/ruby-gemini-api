module Gemini
  class Video
    # サポートされる動画形式
    SUPPORTED_FORMATS = %w[.mp4 .mpeg .mov .avi .flv .mpg .webm .wmv .3gp .3gpp].freeze

    def initialize(client:)
      @client = client
    end

    # 動画ファイルを分析する（Files APIでアップロード後に分析）
    # 20MB以上のファイルや複数回利用する場合に推奨
    def analyze(file: nil, file_path: nil, prompt:, model: "gemini-2.5-flash", **parameters)
      # ファイルパスが指定されている場合はファイルを開く
      if file_path && !file
        file = File.open(file_path, "rb")
        close_file = true
      else
        close_file = false
      end

      begin
        raise ArgumentError, "file or file_path parameter is required" unless file

        # MIMEタイプを判定
        mime_type = parameters.delete(:mime_type) || determine_video_mime_type(file)

        # ファイルをアップロード
        upload_result = @client.files.upload(file: file)
        file_uri = upload_result["file"]["uri"]
        file_name = upload_result["file"]["name"]

        # ファイルがACTIVE状態になるまで待機
        wait_for_file_active(file_name)

        # コンテンツを生成
        raw_response = generate_video_content(
          file_uri: file_uri,
          mime_type: mime_type,
          prompt: prompt,
          model: model,
          **parameters
        )

        # レスポンスとファイル情報を返す
        {
          response: Gemini::Response.new(raw_response),
          file_uri: file_uri,
          file_name: file_name
        }
      ensure
        file.close if file && close_file
      end
    end

    # アップロード済みのファイルURIを使用して分析
    def analyze_with_file_uri(file_uri:, prompt:, model: "gemini-2.5-flash", mime_type: "video/mp4", **parameters)
      raw_response = generate_video_content(
        file_uri: file_uri,
        mime_type: mime_type,
        prompt: prompt,
        model: model,
        **parameters
      )

      Gemini::Response.new(raw_response)
    end

    # YouTube URLから動画を分析（公開動画のみ）
    def analyze_youtube(url:, prompt:, model: "gemini-2.5-flash", **parameters)
      # YouTube URLのバリデーション
      unless valid_youtube_url?(url)
        raise ArgumentError, "Invalid YouTube URL. Only public YouTube videos are supported."
      end

      # リクエストパラメータを構築
      request_params = {
        contents: [{
          parts: [
            { text: prompt },
            {
              file_data: {
                file_uri: url
              }
            }
          ]
        }]
      }

      # 追加パラメータをマージ
      merge_additional_params(request_params, parameters)

      # APIリクエスト
      response = @client.json_post(
        path: "models/#{model}:generateContent",
        parameters: request_params
      )

      Gemini::Response.new(response)
    end

    # 小さい動画ファイルをインラインデータとして分析（20MB未満向け）
    def analyze_inline(file: nil, file_path: nil, prompt:, model: "gemini-2.5-flash", **parameters)
      # ファイルパスが指定されている場合はファイルを開く
      if file_path && !file
        file = File.open(file_path, "rb")
        close_file = true
      else
        close_file = false
      end

      begin
        raise ArgumentError, "file or file_path parameter is required" unless file

        # ファイルサイズチェック（20MB = 20 * 1024 * 1024）
        file.rewind
        file_size = file.size
        if file_size > 20 * 1024 * 1024
          raise ArgumentError, "File size exceeds 20MB. Use analyze method with Files API instead."
        end

        # MIMEタイプを判定
        mime_type = parameters.delete(:mime_type) || determine_video_mime_type(file)

        # Base64エンコード
        file.rewind
        require 'base64'
        file_data = Base64.strict_encode64(file.read)

        # リクエストパラメータを構築
        request_params = {
          contents: [{
            parts: [
              { text: prompt },
              {
                inline_data: {
                  mime_type: mime_type,
                  data: file_data
                }
              }
            ]
          }]
        }

        # 追加パラメータをマージ
        merge_additional_params(request_params, parameters)

        # APIリクエスト
        response = @client.json_post(
          path: "models/#{model}:generateContent",
          parameters: request_params
        )

        Gemini::Response.new(response)
      ensure
        file.close if file && close_file
      end
    end

    # 動画の説明を取得するヘルパーメソッド
    def describe(file: nil, file_path: nil, file_uri: nil, youtube_url: nil, model: "gemini-2.5-flash", language: "ja", **parameters)
      prompt = language == "ja" ? "この動画の内容を詳しく説明してください。" : "Describe this video in detail."

      if youtube_url
        analyze_youtube(url: youtube_url, prompt: prompt, model: model, **parameters)
      elsif file_uri
        analyze_with_file_uri(file_uri: file_uri, prompt: prompt, model: model, **parameters)
      elsif file || file_path
        result = analyze(file: file, file_path: file_path, prompt: prompt, model: model, **parameters)
        result[:response]
      else
        raise ArgumentError, "file, file_path, file_uri, or youtube_url is required"
      end
    end

    # タイムスタンプを抽出するヘルパーメソッド
    def extract_timestamps(file: nil, file_path: nil, file_uri: nil, youtube_url: nil, query:, model: "gemini-2.5-flash", **parameters)
      prompt = "動画内で「#{query}」が登場するタイムスタンプを全て抽出してください。MM:SS形式で出力してください。"

      if youtube_url
        analyze_youtube(url: youtube_url, prompt: prompt, model: model, **parameters)
      elsif file_uri
        analyze_with_file_uri(file_uri: file_uri, prompt: prompt, model: model, **parameters)
      elsif file || file_path
        result = analyze(file: file, file_path: file_path, prompt: prompt, model: model, **parameters)
        result[:response]
      else
        raise ArgumentError, "file, file_path, file_uri, or youtube_url is required"
      end
    end

    # 動画のセグメント（一部分）を分析
    def analyze_segment(file_uri:, prompt:, start_offset: nil, end_offset: nil, model: "gemini-2.5-flash", mime_type: "video/mp4", **parameters)
      # videoMetadataを構築
      video_metadata = {}
      video_metadata[:startOffset] = start_offset if start_offset
      video_metadata[:endOffset] = end_offset if end_offset

      # リクエストパラメータを構築
      file_data_part = {
        file_data: {
          mime_type: mime_type,
          file_uri: file_uri
        }
      }
      file_data_part[:file_data][:video_metadata] = video_metadata unless video_metadata.empty?

      request_params = {
        contents: [{
          parts: [
            { text: prompt },
            file_data_part
          ]
        }]
      }

      # 追加パラメータをマージ
      merge_additional_params(request_params, parameters)

      # APIリクエスト
      response = @client.json_post(
        path: "models/#{model}:generateContent",
        parameters: request_params
      )

      Gemini::Response.new(response)
    end

    # 動画に関する質問に回答
    def ask(file: nil, file_path: nil, file_uri: nil, youtube_url: nil, question:, model: "gemini-2.5-flash", **parameters)
      if youtube_url
        analyze_youtube(url: youtube_url, prompt: question, model: model, **parameters)
      elsif file_uri
        analyze_with_file_uri(file_uri: file_uri, prompt: question, model: model, **parameters)
      elsif file || file_path
        result = analyze(file: file, file_path: file_path, prompt: question, model: model, **parameters)
        result[:response]
      else
        raise ArgumentError, "file, file_path, file_uri, or youtube_url is required"
      end
    end

    private

    # 動画コンテンツを生成する共通メソッド（生のレスポンスを返す）
    def generate_video_content(file_uri:, mime_type:, prompt:, model:, **parameters)
      request_params = {
        contents: [{
          parts: [
            { text: prompt },
            {
              file_data: {
                mime_type: mime_type,
                file_uri: file_uri
              }
            }
          ]
        }]
      }

      # 追加パラメータをマージ
      merge_additional_params(request_params, parameters)

      # APIリクエスト（生のレスポンスを返す）
      @client.json_post(
        path: "models/#{model}:generateContent",
        parameters: request_params
      )
    end

    # 追加パラメータをマージするヘルパー
    def merge_additional_params(request_params, parameters)
      parameters.each do |key, value|
        next if key == :contents
        request_params[key] = value
      end
    end

    # YouTube URLのバリデーション
    def valid_youtube_url?(url)
      youtube_patterns = [
        %r{^https?://(?:www\.)?youtube\.com/watch\?v=[\w-]+},
        %r{^https?://youtu\.be/[\w-]+},
        %r{^https?://(?:www\.)?youtube\.com/embed/[\w-]+},
        %r{^https?://(?:www\.)?youtube\.com/v/[\w-]+},
        %r{^https?://(?:www\.)?youtube\.com/shorts/[\w-]+}
      ]
      youtube_patterns.any? { |pattern| url.match?(pattern) }
    end

    # ファイルがACTIVE状態になるまで待機するメソッド
    def wait_for_file_active(file_name, max_attempts: 30, interval: 2)
      attempts = 0
      loop do
        file_info = @client.files.get(name: file_name)
        state = file_info["state"]

        case state
        when "ACTIVE"
          return true
        when "FAILED"
          raise StandardError, "File processing failed: #{file_info['error']&.dig('message') || 'Unknown error'}"
        else
          # PROCESSING状態の場合は待機
          attempts += 1
          if attempts >= max_attempts
            raise StandardError, "File processing timeout. File is still in #{state} state after #{max_attempts * interval} seconds."
          end
          sleep(interval)
        end
      end
    end

    # 動画のMIMEタイプを判定するヘルパーメソッド
    def determine_video_mime_type(file)
      return "video/mp4" unless file.respond_to?(:path)

      ext = File.extname(file.path).downcase
      case ext
      when ".mp4"
        "video/mp4"
      when ".mpeg", ".mpg"
        "video/mpeg"
      when ".mov"
        "video/quicktime"
      when ".avi"
        "video/x-msvideo"
      when ".flv"
        "video/x-flv"
      when ".webm"
        "video/webm"
      when ".wmv"
        "video/x-ms-wmv"
      when ".3gp", ".3gpp"
        "video/3gpp"
      else
        # デフォルトはMP4
        "video/mp4"
      end
    end
  end
end
