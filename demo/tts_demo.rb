require 'bundler/setup'
require 'gemini'

api_key = ENV['GEMINI_API_KEY'] || 'YOUR_API_KEY_HERE'
client = Gemini::Client.new(api_key)

puts "=== Single-speaker TTS ==="
response = client.generate_speech(
  "Say cheerfully: Have a wonderful day!",
  voice: "Kore"
)
if response.success?
  path = response.save_audio("tts_single.wav")
  puts "Saved: #{path} (#{response.audio_mime_type})"
else
  puts "Error: #{response.error}"
end

puts
puts "=== Multi-speaker TTS ==="
script = <<~SCRIPT
  TTS the following conversation between Joe and Jane:
  Joe: How's it going today, Jane?
  Jane: Not too bad, how about you?
SCRIPT
response = client.generate_speech(
  script,
  multi_speaker: [
    { speaker: "Joe",  voice: "Kore" },
    { speaker: "Jane", voice: "Puck" }
  ]
)
if response.success?
  path = response.save_audio("tts_multi.wav")
  puts "Saved: #{path}"
else
  puts "Error: #{response.error}"
end

puts
puts "=== Style control (single style) ==="
# Note: switching style mid-prompt tends to drop or carry over the previous
# style for the second segment. Stick to one style per call; if you need
# multiple styles, generate each sentence with its own generate_speech call.
response = client.generate_speech(
  "Read this in a soft whisper: I have a secret... and you must never tell anyone.",
  voice: "Zephyr"
)
if response.success?
  path = response.save_audio("tts_style.wav")
  puts "Saved: #{path}"
end

puts
puts "Available voices (#{Gemini::TTS::VOICES.size}):"
puts Gemini::TTS::VOICES.each_slice(5).map { |row| row.join(", ") }.join("\n")
