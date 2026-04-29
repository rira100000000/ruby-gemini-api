require 'bundler/setup'
require 'gemini'

api_key = ENV['GEMINI_API_KEY'] || 'YOUR_API_KEY_HERE'
client = Gemini::Client.new(api_key)

# ヘルパー: コサイン類似度を計算
def cosine_similarity(a, b)
  dot = a.zip(b).sum { |x, y| x * y }
  norm_a = Math.sqrt(a.sum { |x| x * x })
  norm_b = Math.sqrt(b.sum { |x| x * x })
  dot / (norm_a * norm_b)
end

puts "=== 単一テキストの埋め込みベクトル ==="
response = client.embed_content(
  "人生の意味とは何ですか？",
  model: "gemini-embedding-001"
)

if response.success?
  puts "埋め込みベクトルの次元数: #{response.embedding_dimension}"
  puts "最初の5要素: #{response.embedding.first(5).inspect}"
else
  puts "エラー: #{response.error}"
end

puts
puts "=== task_type と output_dimensionality を指定した埋め込み ==="
response = client.embed_content(
  "Rubyは動的なオープンソースのプログラミング言語です。",
  model: "gemini-embedding-001",
  task_type: :retrieval_document,
  title: "Ruby概要",
  output_dimensionality: 768
)

if response.success?
  puts "埋め込みベクトルの次元数: #{response.embedding_dimension}"
end

puts
puts "=== 複数テキストのバッチ埋め込み ==="
texts = [
  "Rubyでプログラミングするのが大好きです。",
  "ルビーは赤い宝石です。",
  "Pythonもプログラミング言語です。",
  "ダイヤモンドは永遠の輝き。"
]

response = client.embed_content(
  texts,
  model: "gemini-embedding-001",
  task_type: :semantic_similarity
)

if response.success?
  vectors = response.embeddings
  puts "次元数 #{vectors.first.size} のベクトルを #{vectors.size} 件取得しました"
  puts

  puts "コサイン類似度（プログラミング vs 宝石）:"
  vectors.each_with_index do |v1, i|
    vectors.each_with_index do |v2, j|
      next if i >= j
      sim = cosine_similarity(v1, v2)
      printf "  [%d] vs [%d]: %.4f  | %s | %s\n", i, j, sim, texts[i], texts[j]
    end
  end
else
  puts "エラー: #{response.error}"
end
