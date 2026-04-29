require 'bundler/setup'
require 'gemini'

api_key = ENV['GEMINI_API_KEY'] || 'YOUR_API_KEY_HERE'
client = Gemini::Client.new(api_key)

# Helper: cosine similarity between two vectors
def cosine_similarity(a, b)
  dot = a.zip(b).sum { |x, y| x * y }
  norm_a = Math.sqrt(a.sum { |x| x * x })
  norm_b = Math.sqrt(b.sum { |x| x * x })
  dot / (norm_a * norm_b)
end

puts "=== Single embedding ==="
response = client.embed_content(
  "What is the meaning of life?",
  model: "gemini-embedding-001"
)

if response.success?
  puts "Embedding dimension: #{response.embedding_dimension}"
  puts "First 5 values: #{response.embedding.first(5).inspect}"
else
  puts "Error: #{response.error}"
end

puts
puts "=== Single embedding with task_type and output_dimensionality ==="
response = client.embed_content(
  "Ruby is a dynamic, open-source programming language.",
  model: "gemini-embedding-001",
  task_type: :retrieval_document,
  title: "Ruby Overview",
  output_dimensionality: 768
)

if response.success?
  puts "Embedding dimension: #{response.embedding_dimension}"
end

puts
puts "=== Batch embeddings ==="
texts = [
  "I love programming in Ruby.",
  "Rubies are red gemstones.",
  "Python is also a programming language.",
  "Diamonds are forever."
]

response = client.embed_content(
  texts,
  model: "gemini-embedding-001",
  task_type: :semantic_similarity
)

if response.success?
  vectors = response.embeddings
  puts "Got #{vectors.size} embedding vectors of dimension #{vectors.first.size}"
  puts

  # Show similarity matrix
  puts "Cosine similarities (programming vs gemstones):"
  vectors.each_with_index do |v1, i|
    vectors.each_with_index do |v2, j|
      next if i >= j
      sim = cosine_similarity(v1, v2)
      printf "  [%d] vs [%d]: %.4f  | %s | %s\n", i, j, sim, texts[i], texts[j]
    end
  end
else
  puts "Error: #{response.error}"
end
