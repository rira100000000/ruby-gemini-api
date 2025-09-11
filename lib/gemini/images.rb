module Gemini
  class Images
    def initialize(client:)
      @client = client
    end

    # 画像を生成するメインメソッド
    def generate(parameters: {})
      prompt = parameters[:prompt]
      raise ArgumentError, "prompt parameter is required" unless prompt

      # モデルの決定（デフォルトはGemini 2.5）
      model = parameters[:model] || "gemini-2.5-flash-image-preview"
      
      # 入力画像がある場合は画像編集モード
      if parameters[:image] || parameters[:image_path] || parameters[:image_base64]
        return generate_with_image(prompt, model, parameters)
      end
      
      # モデルに応じた画像生成処理
      if model.start_with?("imagen")
        # Imagen 3を使用
        response = imagen_generate(prompt, parameters)
      else
        # Gemini 2.0を使用
        response = gemini_generate(prompt, parameters)
      end
      
      # レスポンスをラップして返す
      Gemini::Response.new(response)
    end
    
    private
    
    # 画像+テキストによる画像生成（新規追加）
    def generate_with_image(prompt, model, parameters)
      # 画像編集用のモデルを使用（明示的に指定されていない場合）
      if model == "gemini-2.0-flash-exp-image-generation"
        model = "gemini-2.5-flash-image-preview"
      end
      
      # 画像データの処理
      image_data = process_input_image(parameters)
      
      # コンテンツ部分の構築
      parts = [
        { "text" => prompt },
        {
          "inline_data" => {
            "mime_type" => image_data[:mime_type],
            "data" => image_data[:data]
          }
        }
      ]
      
      # 生成設定の構築
      generation_config = {
        "responseModalities" => ["Image"]
      }
      
      # 温度設定があれば追加
      if parameters[:temperature]
        generation_config["temperature"] = parameters[:temperature]
      end
      
      # リクエストパラメータの構築
      request_params = {
        "contents" => [{
          "parts" => parts
        }],
        "generationConfig" => generation_config
      }
      
      # その他のパラメータをマージ（除外するキーを指定）
      excluded_keys = [:prompt, :image, :image_path, :image_base64, :model, :temperature]
      parameters.each do |key, value|
        next if excluded_keys.include?(key)
        request_params[key.to_s] = value
      end
      
      # API呼び出し
      response = @client.json_post(
        path: "models/#{model}:generateContent",
        parameters: request_params
      )
      
      Gemini::Response.new(response)
    end

    # 入力画像の処理（新規追加）
    def process_input_image(parameters)
      if parameters[:image_base64]
        # Base64データが直接提供された場合
        {
          data: parameters[:image_base64],
          mime_type: parameters[:mime_type] || "image/jpeg"
        }
      elsif parameters[:image_path]
        # ファイルパスが提供された場合
        process_image_file(parameters[:image_path])
      elsif parameters[:image]
        # ファイルオブジェクトが提供された場合
        if parameters[:image].respond_to?(:read)
          process_image_io(parameters[:image])
        else
          raise ArgumentError, "Invalid image parameter. Expected file path, file object, or base64 data."
        end
      else
        raise ArgumentError, "No image data provided"
      end
    end

    # ファイルパスから画像を処理（新規追加）
    def process_image_file(file_path)
      raise ArgumentError, "File does not exist: #{file_path}" unless File.exist?(file_path)
      
      require 'base64'
      
      # MIMEタイプを判定
      mime_type = determine_image_mime_type(file_path)
      
      # ファイルを読み込んでBase64エンコード
      file_data = File.binread(file_path)
      base64_data = Base64.strict_encode64(file_data)
      
      {
        data: base64_data,
        mime_type: mime_type
      }
    end

    # IOオブジェクトから画像を処理（新規追加）
    def process_image_io(image_io)
      require 'base64'
      
      # ファイルの先頭に移動
      image_io.rewind if image_io.respond_to?(:rewind)
      
      # データを読み込み
      file_data = image_io.read
      
      # MIMEタイプを判定（ファイルパスがあれば使用、なければ内容から推測）
      mime_type = if image_io.respond_to?(:path) && image_io.path
                    determine_image_mime_type(image_io.path)
                  else
                    determine_mime_type_from_content(file_data)
                  end
      
      # Base64エンコード
      base64_data = Base64.strict_encode64(file_data)
      
      {
        data: base64_data,
        mime_type: mime_type
      }
    end

    # ファイルパスから画像のMIMEタイプを判定（新規追加）
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
        # デフォルトはJPEG
        "image/jpeg"
      end
    end

    # ファイル内容からMIMEタイプを判定（新規追加）
    def determine_mime_type_from_content(data)
      return "image/jpeg" if data.nil? || data.empty?
      
      # ファイルヘッダーをチェック
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
        # デフォルトはJPEG
        "image/jpeg"
      end
    end

    # Gemini 2.0モデルを使用した画像生成（元のコードそのまま）
    def gemini_generate(prompt, parameters)
      # パラメータの準備
      model = parameters[:model] || "gemini-2.0-flash-exp-image-generation"
      
      # サイズパラメータの処理（現在はGemini APIでは使用しない）
      # aspect_ratio = process_size_parameter(parameters[:size])
      
      # 生成設定の構築
      generation_config = {
        "responseModalities" => ["Text", "Image"]
      }
      
      # リクエストパラメータの構築
      request_params = {
        "contents" => [{
          "parts" => [
            {"text" => prompt}
          ]
        }],
        "generationConfig" => generation_config
      }
      
      # API呼び出し
      @client.json_post(
        path: "models/#{model}:generateContent",
        parameters: request_params
      )
    end
    
    # Imagen 3モデルを使用した画像生成（元のコードそのまま）
    def imagen_generate(prompt, parameters)
      # モデル名の取得（デフォルトはImagen 3の標準モデル）
      model = parameters[:model] || "imagen-3.0-generate-002"
      
      # サイズパラメータからアスペクト比を取得
      aspect_ratio = process_size_parameter(parameters[:size])
      
      # 画像生成数の設定
      sample_count = parameters[:n] || parameters[:sample_count] || 1
      sample_count = [[sample_count.to_i, 1].max, 4].min # 1〜4の範囲に制限
      
      # 人物生成の設定
      person_generation = parameters[:person_generation] || "ALLOW_ADULT"
      
      # リクエストパラメータの構築
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
      
      # アスペクト比が指定されている場合は追加
      request_params["parameters"]["aspectRatio"] = aspect_ratio if aspect_ratio
      
      # 人物生成設定を追加
      request_params["parameters"]["personGeneration"] = person_generation
      
      # API呼び出し
      @client.json_post(
        path: "models/#{model}:predict",
        parameters: request_params
      )
    end
    
    # サイズパラメータからアスペクト比を決定（元のコードそのまま）
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
        "1:1" # デフォルト
      end
    end
  end
end