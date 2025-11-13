require 'bundler/setup'
require 'gemini'

# コマンドライン引数からURLとオプションを取得
url = nil
use_url_context = true

ARGV.each do |arg|
  if arg == '--no-context' || arg == '--off'
    use_url_context = false
  elsif !arg.start_with?('--')
    url = arg
  end
end

unless url
  puts "使用方法: ruby url_context_demo_ja.rb <URL> [--no-context]"
  puts "例: ruby url_context_demo_ja.rb https://www.ruby-lang.org/ja/"
  puts "    ruby url_context_demo_ja.rb https://www.ruby-lang.org/ja/ --no-context"
  puts ""
  puts "オプション:"
  puts "  --no-context  URL Contextをオフにして実行"
  exit 1
end

api_key = ENV['GEMINI_API_KEY'] || raise("GEMINI_API_KEY環境変数を設定してください")

begin
  puts "Geminiクライアントを初期化中..."
  client = Gemini::Client.new(api_key)

  puts "Gemini URL Context デモ"
  puts "==================================="
  puts "URL: #{url}"
  puts "URL Context: #{use_url_context ? 'オン' : 'オフ'}"
  puts "==================================="

  # URLの内容を要約
  puts "\nURLの内容を要約しています..."
  response = client.generate_content(
    "このページの内容を日本語で詳しく要約してください: #{url}",
    model: "gemini-2.5-flash",
    url_context: use_url_context
  )

  if response.success?
    puts "\n要約:"
    puts response.text

    # デバッグ: 生のレスポンスを確認
    if ENV["DEBUG"]
      puts "\n--- デバッグ: 生のレスポンス ---"
      require 'json'
      puts JSON.pretty_generate(response.raw_data)
    end

    # URL Context メタデータを表示
    if response.url_context?
      puts "\n--- URL Context 情報 ---"
      puts "取得されたURL数: #{response.retrieved_urls.length}"

      response.url_retrieval_statuses.each_with_index do |url_info, i|
        puts "\n#{i+1}. URL: #{url_info[:url]}"
        puts "   ステータス: #{url_info[:status]}"
        puts "   タイトル: #{url_info[:title]}" if url_info[:title]
      end
    else
      puts "\n[情報] URL Contextメタデータが見つかりませんでした"
      if ENV["DEBUG"]
        puts "first_candidate keys: #{response.first_candidate&.keys&.inspect}"
      end
    end
  else
    puts "エラー: #{response.error}"
  end

  puts "\n==================================="
  puts "デモ完了"

rescue StandardError => e
  puts "\nエラーが発生しました: #{e.message}"
  puts e.backtrace.join("\n") if ENV["DEBUG"]
end
