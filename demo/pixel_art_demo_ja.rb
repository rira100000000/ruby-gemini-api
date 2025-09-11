#!/usr/bin/env ruby

require_relative '../lib/gemini'
require 'fileutils'
require 'pathname'

def main
  if ARGV.empty?
    puts "使用方法: ruby pixel_art_demo_ja.rb <画像パス> [出力パス]"
    puts ""
    puts "例："
    puts "  ruby pixel_art_demo_ja.rb photo.jpg"
    puts "  ruby pixel_art_demo_ja.rb photo.jpg pixel_art.png"
    puts "  ruby pixel_art_demo_ja.rb /path/to/image.png custom_output.png"
    exit 1
  end

  image_path = ARGV[0]
  output_path = ARGV[1] || generate_output_filename(image_path)

  # 画像ファイルの存在確認
  unless File.exist?(image_path)
    puts "エラー: 画像ファイル '#{image_path}' が見つかりません。"
    exit 1
  end

  # API キーの確認
  api_key = ENV['GEMINI_API_KEY']
  unless api_key
    puts "エラー: GEMINI_API_KEY 環境変数が設定されていません。"
    puts "Gemini API キーを設定してください："
    puts "export GEMINI_API_KEY='あなたのAPIキー'"
    exit 1
  end

  puts "🎮 Gemini 画像ドット絵変換ツール"
  puts "=" * 50
  puts "入力画像: #{image_path}"
  puts "出力先: #{output_path}"
  puts ""

  # Geminiクライアントを初期化
  begin
    client = Gemini::Client.new(api_key)
    puts "✅ Geminiクライアントの初期化が完了しました"
  rescue => e
    puts "❌ Geminiクライアントの初期化に失敗しました: #{e.message}"
    exit 1
  end

  # 画像をドット絵に変換
  puts ""
  puts "🔄 画像をドット絵に変換しています..."
  puts "しばらくお待ちください..."

  begin
    response = client.images.generate(
      parameters: {
        prompt: create_pixel_art_prompt,
        image_path: image_path,
        model: "gemini-2.5-flash-image-preview",
        temperature: 0.7
      }
    )

    if response.success? && !response.images.empty?
      puts "✅ ドット絵の生成が完了しました！"
      
      # 画像を保存
      saved_file = response.save_image(output_path)
      
      if saved_file
        puts "💾 ドット絵を保存しました: #{saved_file}"
        
        # ファイルサイズを表示
        file_size = File.size(saved_file)
        puts "📁 ファイルサイズ: #{format_file_size(file_size)}"
        
        puts ""
        puts "🎉 変換が正常に完了しました！"
        puts "'#{saved_file}' を開いてドット絵をご確認ください！"
      else
        puts "❌ 生成された画像の保存に失敗しました"
        exit 1
      end
    else
      puts "❌ ドット絵の生成に失敗しました"
      if response.error
        puts "エラー: #{response.error}"
      end
      exit 1
    end

  rescue => e
    puts "❌ 変換中にエラーが発生しました: #{e.message}"
    if ENV['DEBUG']
      puts "デバッグ情報:"
      puts e.backtrace.join("\n")
    end
    exit 1
  end
end

# リトライ機能付きで画像生成を実行
def generate_with_retry(client, image_path, max_retries = 3)
  retry_count = 0
  
  # 画像ファイルの詳細情報をデバッグ表示
  puts "🔍 画像ファイル情報:"
  file_size = File.size(image_path)
  puts "  パス: #{image_path}"
  puts "  サイズ: #{format_file_size(file_size)}"
  puts "  MIMEタイプ: #{determine_image_mime_type_debug(image_path)}"
  puts ""
  
  loop do
    begin
      puts "🚀 API呼び出し中... (#{retry_count + 1}回目)"
      puts "  モデル: gemini-2.5-flash-image-preview"
      puts "  プロンプト: #{create_pixel_art_prompt[0..100]}..."
      
      response = client.images.generate(
        parameters: {
          prompt: create_pixel_art_prompt,
          image_path: image_path,
          model: "gemini-2.5-flash-image-preview",
          temperature: 0.7
        }
      )
      
      puts "📥 レスポンス受信完了"
      return response
      
    rescue => e
      puts "⚠️  エラーが発生しました: #{e.class}: #{e.message}"
      
      if e.message.include?("429") && retry_count < max_retries
        retry_count += 1
        wait_time = [30, 60, 120][retry_count - 1] # 30秒、1分、2分待機
        puts "⚠️  API制限のため待機中... (#{retry_count}/#{max_retries}回目のリトライ)"
        puts "⏰ #{wait_time}秒待機します..."
        sleep(wait_time)
        next
      else
        puts "❌ 最大リトライ回数に達したか、致命的なエラーです"
        puts "エラーの詳細: #{e.backtrace.first(3).join("\n")}" if ENV['DEBUG']
        raise e
      end
    end
  end
end

# デバッグ用のMIMEタイプ判定
def determine_image_mime_type_debug(file_path)
  ext = File.extname(file_path).downcase
  
  # ファイルヘッダーも確認
  header_info = ""
  if File.exist?(file_path)
    File.open(file_path, 'rb') do |file|
      header = file.read(8)
      header_bytes = header.bytes.map { |b| sprintf("%02x", b) }.join(" ")
      header_info = " (ヘッダー: #{header_bytes})"
    end
  end
  
  case ext
  when ".jpg", ".jpeg"
    "image/jpeg#{header_info}"
  when ".png"
    "image/png#{header_info}"
  when ".gif"
    "image/gif#{header_info}"
  when ".webp"
    "image/webp#{header_info}"
  else
    "不明#{header_info}"
  end
end

# ドット絵変換用のプロンプトを作成
def create_pixel_art_prompt
  prompts = [
    "この画像を鮮やかな色と明確なピクセル境界を持つレトロな8ビットピクセルアートスタイルに変換してください",
    "この画像を限定的なカラーパレットを使用したクラシックなビデオゲームの美学でピクセルアートに変換してください", 
    "シャープでブロック状のピクセルとレトロゲームスタイルの色を使ってこの画像のピクセルアート版を作成してください",
    "鮮明なピクセル定義を持つクラシックな16ビットビデオゲームに似たピクセルアートに変換してください",
    "この画像を大胆でカラフルなピクセルとレトロゲームの美学を持つ8ビットピクセルアートスタイルに変換してください"
  ]
  
  # ランダムにプロンプトを選択（バリエーションのため）
  prompts.sample
end

# 出力ファイル名を生成
def generate_output_filename(input_path)
  path = Pathname.new(input_path)
  dir = path.dirname
  basename = path.basename(path.extname)
  
  # タイムスタンプを追加してファイル名の重複を避ける
  timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
  
  # PNG形式で保存（ドット絵に適している）
  File.join(dir, "#{basename}_pixel_art_#{timestamp}.png")
end

# ファイルサイズを読みやすい形式にフォーマット
def format_file_size(size)
  units = ['B', 'KB', 'MB', 'GB']
  unit_index = 0
  size_float = size.to_f
  
  while size_float >= 1024 && unit_index < units.length - 1
    size_float /= 1024
    unit_index += 1
  end
  
  if unit_index == 0
    "#{size_float.to_i} #{units[unit_index]}"
  else
    "%.1f #{units[unit_index]}" % size_float
  end
end

# スクリプトが直接実行された場合のみmainを呼び出し
if __FILE__ == $0
  main
end