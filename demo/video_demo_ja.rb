require 'bundler/setup'
require 'gemini'
require 'logger'

# ロガーの設定
logger = Logger.new(STDOUT)
logger.level = Logger::INFO

# APIキーを環境変数から取得
api_key = ENV['GEMINI_API_KEY'] || raise("GEMINI_API_KEY環境変数を設定してください")

begin
  # クライアントの初期化
  logger.info "Geminiクライアントを初期化しています..."
  client = Gemini::Client.new(api_key)

  puts "動画理解機能デモ"
  puts "==============================================="

  # コマンドライン引数の処理
  if ARGV.empty?
    puts "使用方法:"
    puts "  ファイル分析:   ruby video_demo_ja.rb <動画ファイルのパス>"
    puts "  YouTube分析:   ruby video_demo_ja.rb --youtube <YouTube URL>"
    puts ""
    puts "例:"
    puts "  ruby video_demo_ja.rb sample.mp4"
    puts "  ruby video_demo_ja.rb --youtube https://www.youtube.com/watch?v=XXXXX"
    puts ""
    puts "サポートされる動画形式: MP4, MPEG, MOV, AVI, FLV, MPG, WebM, WMV, 3GPP"
    exit 1
  end

  # 処理開始時間
  start_time = Time.now

  if ARGV[0] == "--youtube"
    # YouTube URL分析モード
    youtube_url = ARGV[1] || raise("YouTube URLを指定してください")

    puts "YouTube動画を分析しています..."
    puts "URL: #{youtube_url}"
    puts "==============================================="

    # 動画の説明を取得
    puts "\n=== 動画の説明 ==="
    response = client.video.describe(youtube_url: youtube_url)

    if response.valid?
      puts response.text
    else
      puts "エラー: #{response.error || '不明なエラー'}"
    end

    # カスタム質問
    puts "\n=== 動画に関する質問 ==="
    question = "この動画の主なポイントを3つ挙げてください。"
    puts "質問: #{question}"
    puts ""

    response = client.video.ask(youtube_url: youtube_url, question: question)

    if response.valid?
      puts response.text
    else
      puts "エラー: #{response.error || '不明なエラー'}"
    end

  else
    # ローカルファイル分析モード
    video_file_path = ARGV[0]

    # ファイルの存在確認
    unless File.exist?(video_file_path)
      raise "ファイルが見つかりません: #{video_file_path}"
    end

    # ファイル情報を表示
    file_size = File.size(video_file_path) / 1024.0 / 1024.0 # MB単位
    file_extension = File.extname(video_file_path)
    puts "ファイル: #{File.basename(video_file_path)}"
    puts "サイズ: #{file_size.round(2)} MB"
    puts "タイプ: #{file_extension}"
    puts "==============================================="

    # ファイルサイズに応じた処理方法を選択
    if file_size < 20
      puts "インラインデータとして処理します（20MB未満）..."

      # 小さいファイルはインラインデータとして処理
      response = client.video.analyze_inline(
        file_path: video_file_path,
        prompt: "この動画の内容を詳しく説明してください。"
      )

      puts "\n=== 動画の説明 ==="
      if response.valid?
        puts response.text
      else
        puts "エラー: #{response.error || '不明なエラー'}"
      end
    else
      puts "Files APIを使用してアップロードします（20MB以上）..."
      puts "アップロード後、ファイル処理が完了するまで待機します..."

      # 大きいファイルはFiles APIでアップロード
      result = client.video.analyze(
        file_path: video_file_path,
        prompt: "この動画の内容を詳しく説明してください。"
      )

      puts "\n=== 動画の説明 ==="
      if result[:response].valid?
        puts result[:response].text
      else
        puts "エラー: #{result[:response].error || '不明なエラー'}"
      end

      puts "\n=== ファイル情報 ==="
      puts "File URI: #{result[:file_uri]}"
      puts "File Name: #{result[:file_name]}"

      # アップロードしたファイルで追加の質問
      puts "\n=== 追加の質問 ==="
      question = "この動画に登場する人物や物体を列挙してください。"
      puts "質問: #{question}"
      puts ""

      response = client.video.ask(
        file_uri: result[:file_uri],
        question: question
      )

      if response.valid?
        puts response.text
      else
        puts "エラー: #{response.error || '不明なエラー'}"
      end

      # タイムスタンプ抽出の例
      puts "\n=== タイムスタンプ抽出 ==="
      query = "重要なシーン"
      puts "検索: #{query}"
      puts ""

      response = client.video.extract_timestamps(
        file_uri: result[:file_uri],
        query: query
      )

      if response.valid?
        puts response.text
      else
        puts "エラー: #{response.error || '不明なエラー'}"
      end

      puts "\nファイルは48時間後に自動的に削除されます"
    end
  end

  # 処理終了時間と経過時間の計算
  end_time = Time.now
  elapsed_time = end_time - start_time

  puts "\n==============================================="
  puts "処理時間: #{elapsed_time.round(2)} 秒"

rescue StandardError => e
  logger.error "エラーが発生しました: #{e.message}"
  logger.error e.backtrace.join("\n") if ENV["DEBUG"]

  puts "\n詳細エラー情報:"
  puts "#{e.class}: #{e.message}"

  # APIエラーの詳細情報
  if defined?(Faraday::Error) && e.is_a?(Faraday::Error)
    puts "API接続エラー: #{e.message}"
    if e.response
      puts "レスポンスステータス: #{e.response[:status]}"
      puts "レスポンスボディ: #{e.response[:body]}"
    end
  end
end
