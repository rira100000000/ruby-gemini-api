#!/usr/bin/env ruby

require 'pathname'
require 'gemini'

def main
  if ARGV.length < 2
    puts "使用方法: ruby image_generation_with_multi_image.rb <画像1> <画像2> [出力ファイル]"
    puts ""
    puts "例："
    puts "  ruby image_generation_with_multi_image.rb cat.png dog.jpg"
    puts "  ruby image_generation_with_multi_image.rb photo1.jpg photo2.png result.png"
    exit 1
  end

  image1_path = ARGV[0]
  image2_path = ARGV[1]
  output_path = ARGV[2] || generate_output_filename(image1_path, image2_path)

  # 画像ファイルの存在確認
  [image1_path, image2_path].each_with_index do |path, index|
    unless File.exist?(path)
      puts "❌ 画像ファイル#{index + 1} '#{path}' が見つかりません。"
      exit 1
    end
  end

  # API キーの確認
  api_key = ENV['GEMINI_API_KEY']
  unless api_key
    puts "❌ GEMINI_API_KEY 環境変数が設定されていません。"
    puts "Gemini API キーを設定してください："
    puts "export GEMINI_API_KEY='あなたのAPIキー'"
    exit 1
  end

  puts "🎨 Gemini 複数画像合成ツール"
  puts "=" * 50
  puts "📷 画像1: #{File.basename(image1_path)} (#{format_file_size(File.size(image1_path))})"
  puts "📷 画像2: #{File.basename(image2_path)} (#{format_file_size(File.size(image2_path))})"
  puts "💾 出力先: #{File.basename(output_path)}"
  puts ""

  # プロンプト入力
  prompt = get_user_prompt

  # 画像生成
  puts ""
  puts "🔄 画像を生成しています..."
  puts "   プロンプト: \"#{prompt[0..60]}#{prompt.length > 60 ? '...' : ''}\""
  puts "   しばらくお待ちください..."

  begin
    # Geminiクライアントを初期化
    client = Gemini::Client.new(api_key)
    puts "✅ Geminiクライアントの初期化が完了しました"
    
    # client.images.generateを使用して画像生成
    puts "🚀 APIを呼び出し中..."
    response = client.images.generate(
      parameters: {
        prompt: prompt,
        image_paths: [image1_path, image2_path],
        model: "gemini-2.5-flash-image-preview",
        temperature: 0.7
      }
    )

    if response.success? && response.images.any?
      puts "✅ 画像の生成が完了しました！"
      
      # 画像を保存
      saved_file = response.save_image(output_path)
      
      if saved_file
        puts "💾 生成された画像を保存しました: #{saved_file}"
        puts "📁 ファイルサイズ: #{format_file_size(File.size(saved_file))}"
        puts ""
        puts "🎉 生成が正常に完了しました！"
        puts "   '#{saved_file}' を開いて生成された画像をご確認ください！"
      else
        puts "❌ 生成された画像の保存に失敗しました"
        exit 1
      end
    else
      puts "❌ 画像の生成に失敗しました"
      if response.error
        puts "   理由: #{response.error}"
      elsif response.finish_reason
        puts "   終了理由: #{response.finish_reason}"
      end
      exit 1
    end

  rescue => e
    puts "❌ 生成中にエラーが発生しました: #{e.message}"
    if ENV['DEBUG']
      puts "デバッグ情報:"
      puts e.backtrace.join("\n")
    end
    exit 1
  end
end

# ユーザーからプロンプトを取得
def get_user_prompt
  puts "📝 生成したい画像の説明を入力してください："
  puts ""
  
  # サンプルプロンプトを表示
  puts "💡 プロンプトの例："
  puts "   - この2匹の動物が一緒に遊んでいる画像を作成してください"
  puts "   - 画像を合成してください"
  puts "   - 両方の画像の要素を組み合わせたアート作品を生成してください"
  puts ""
  
  print "👉 プロンプト: "
  prompt = STDIN.gets.chomp.strip
  
  # プロンプトが空の場合はデフォルトを使用
  if prompt.empty?
    prompt = "Create an artistic composition by combining elements from both input images"
    puts "   デフォルトプロンプトを使用します: #{prompt}"
  end
  
  puts ""
  
  prompt
end

# 出力ファイル名を生成
def generate_output_filename(image1_path, image2_path)
  path1 = Pathname.new(image1_path)
  path2 = Pathname.new(image2_path)
  
  # 最初の画像があるディレクトリを使用
  dir = path1.dirname
  
  # ベース名を組み合わせ
  basename1 = path1.basename(path1.extname)
  basename2 = path2.basename(path2.extname)
  
  # タイムスタンプを追加
  timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
  
  # PNG形式で保存
  File.join(dir, "#{basename1}_#{basename2}_combined_#{timestamp}.png")
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