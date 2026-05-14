require 'bundler/setup'
require 'gemini'

api_key = ENV['GEMINI_API_KEY'] || 'YOUR_API_KEY_HERE'
client = Gemini::Client.new(api_key)

puts "=== 単一話者の音声合成 ==="
response = client.generate_speech(
  "明るく言ってください: 今日も素晴らしい一日になりますように！",
  voice: "Kore"
)
if response.success?
  path = response.save_audio("tts_single_ja.wav")
  puts "保存しました: #{path} (#{response.audio_mime_type})"
else
  puts "エラー: #{response.error}"
end

puts
puts "=== 複数話者の音声合成 ==="
script = <<~SCRIPT
  以下の会話を音声合成してください：
  Joe: ジェーン、今日の調子はどう？
  Jane: まあまあかな、あなたは？
SCRIPT
response = client.generate_speech(
  script,
  multi_speaker: [
    { speaker: "Joe",  voice: "Kore" },
    { speaker: "Jane", voice: "Puck" }
  ]
)
if response.success?
  path = response.save_audio("tts_multi_ja.wav")
  puts "保存しました: #{path}"
else
  puts "エラー: #{response.error}"
end

puts
puts "=== スタイル指定（ささやき声）==="
# 注: 1つのプロンプト内で複数のスタイルを切り替えると、後半が
# 前のスタイルを引きずったり無音化する傾向があるため、ここでは
# スタイルを1つに絞った例を示します。複数スタイルを使い分けたい
# 場合は、文ごとに generate_speech を分けるのが安定します。
response = client.generate_speech(
  "ゆっくりとささやくように読み上げてください: 秘密があるんだ……これは誰にも言わないでね。",
  voice: "Zephyr"
)
if response.success?
  path = response.save_audio("tts_style_ja.wav")
  puts "保存しました: #{path}"
end

puts
puts "利用可能なボイス (#{Gemini::TTS::VOICES.size}種類):"
puts Gemini::TTS::VOICES.each_slice(5).map { |row| row.join(", ") }.join("\n")
