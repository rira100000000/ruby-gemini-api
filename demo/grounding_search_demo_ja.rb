require 'bundler/setup'
require 'gemini'

api_key = ENV['GEMINI_API_KEY'] || raise("GEMINI_API_KEY環境変数を設定してください")

begin
  puts "Geminiクライアントを初期化中..."
  client = Gemini::Client.new(api_key)
  
  puts "Gemini グラウンディング検索デモ"
  puts "==================================="

  # Google検索を使用してリアルタイム情報を取得
  response = client.generate_content(
    "ビートルズに影響を受けた日本人アーティストを教えて。",
    model: "gemini-2.0-flash-lite",
    tools: [{ google_search: {} }]
  )
  
  if response.success?
    puts "\n回答:"
    puts response.text
    
    # グラウンディングメタデータがあれば表示
    if response.grounding_metadata
      puts "\n--- グラウンディング情報 ---"
      puts "検索エントリーポイント: #{response.grounding_metadata['searchEntryPoint']}" if response.grounding_metadata['searchEntryPoint']
      
      if response.grounding_metadata['groundingChunks']
        puts "\n参照したソース:"
        response.grounding_metadata['groundingChunks'].each_with_index do |chunk, i|
          if chunk['web']
            puts "#{i+1}. #{chunk['web']['title']}"
            puts "   URL: #{chunk['web']['uri']}"
          end
        end
      end
    end
  else
    puts "エラー: #{response.error}"
  end
  
  puts "\n==================================="
  
  # 別の例: 最新のニュースを取得
  puts "\n最新情報の取得例:"
  response2 = client.generate_content(
    "今日の日本のニュースを教えて",
    model: "gemini-2.0-flash-lite",
    tools: [{ google_search: {} }]
  )
  
  if response2.success?
    puts response2.text
  end
  
  puts "\nデモ完了"

rescue StandardError => e
  puts "\nエラーが発生しました: #{e.message}"
  puts e.backtrace.join("\n") if ENV["DEBUG"]
end