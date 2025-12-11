require 'bundler/setup'
require 'gemini'
require 'logger'
require 'json'

logger = Logger.new(STDOUT)
logger.level = Logger::DEBUG
ENV["DEBUG"] = "true"

api_key = ENV['GEMINI_API_KEY'] || raise("GEMINI_API_KEY環境変数を設定してください")

begin
  puts "Geminiクライアントを初期化しています..."
  client = Gemini::Client.new(api_key)
  
  # ファイルURIを引数から取得
  file_uri = ARGV[0] || raise("使用方法: ruby cache_test.rb <file_uri> [mime_type]")
  
  # MIMEタイプ（指定がなければデフォルト値）
  mime_type = ARGV[1] || "application/pdf"
  
  puts "file_uri: #{file_uri}"
  puts "mime_type: #{mime_type}"
  
  # システム指示を設定
  system_instruction = "あなたはドキュメント分析の専門家です。与えられたドキュメントの内容を正確に把握し、質問に詳細に答えてください。"
  
  # HTTP通信ログを有効化
  Faraday.default_connection.response :logger, logger, { headers: true, bodies: true }
  
  puts "キャッシュリクエストを準備中..."
  
  # キャッシュリクエストを構築
  request = {
    model: "gemini-2.5-flash",
    contents: [
      {
        parts: [
          { file_data: { mime_type: mime_type, file_uri: file_uri } }
        ],
        role: "user"
      }
    ],
    system_instruction: {
      parts: [{ text: system_instruction }],
      role: "system"
    },
    ttl: "3600s"
  }
  
  puts "リクエスト内容:"
  puts JSON.pretty_generate(request)
  
  puts "キャッシュAPIを呼び出し中..."
  
  begin
    # キャッシュに保存
    cache_response = client.json_post(
      path: "cachedContents",
      parameters: request
    )
    
    puts "キャッシュAPI呼び出し成功！"
    puts "レスポンス:"
    puts cache_response.inspect
    
    if cache_response.is_a?(Hash) && cache_response["name"]
      puts "キャッシュ名: #{cache_response["name"]}"
    else
      puts "キャッシュ名が見つかりません。レスポンス形式を確認してください。"
    end
  rescue => e
    puts "キャッシュ作成エラー: #{e.message}"
    # エラーレスポンスを取得する試み
    if e.respond_to?(:response) && e.response
      puts "エラーレスポンス:"
      puts e.response.inspect
      if e.response[:body].is_a?(String)
        begin
          error_json = JSON.parse(e.response[:body])
          puts "エラー詳細: #{error_json.inspect}"
        rescue
          puts "エラーボディ: #{e.response[:body]}"
        end
      end
    end
    raise e
  end
  
rescue StandardError => e
  logger.error "エラーが発生しました: #{e.message}"
  logger.error e.backtrace.join("\n")
end