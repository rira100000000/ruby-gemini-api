## [Unreleased]

### Added
- TTS (speech generation) API support
  - `client.tts.generate(text, voice:)` and `client.generate_speech(text, voice:)` shortcut
  - Single-speaker mode via `voice:` and multi-speaker mode via `multi_speaker: [{ speaker:, voice: }, ...]`
  - 30 prebuilt voices exposed as `Gemini::TTS::VOICES`
  - Default model `gemini-2.5-flash-preview-tts` (override via `model:`)
  - `Response` helpers: `#audio_data`, `#audio_mime_type`, `#audio_response?`, `#save_audio(path)` which auto-wraps L16 PCM in a RIFF/WAVE header
  - Demos: `tts_demo.rb` / `tts_demo_ja.rb`
- `countTokens` API support
  - `client.tokens.count(input, ...)` and `client.count_tokens(input, ...)` shortcut
  - Accepts String / Array / Hash inputs, full `contents:` array, plus optional `system_instruction:`, `tools:`, `generation_config:`, `cached_content:` (auto-wraps payload in `generateContentRequest` when extra fields are present)
  - `Response` helpers: `#count_tokens`, `#prompt_tokens_details`, `#cached_content_token_count`, `#count_tokens_response?`
  - Demos: `count_tokens_demo.rb` / `count_tokens_demo_ja.rb`

## [1.1.0] - 2026-04-29

### Added
- Live API support for real-time bidirectional audio/video/text conversations over WebSocket
  - `Gemini::Live::Session` with event-driven API (`:setup_complete`, `:text`, `:audio`, `:tool_call`, `:turn_complete`, `:interrupted`, `:usage_metadata`, `:session_resumption`, `:go_away`, `:close`, `:error`)
  - `Gemini::Live::Configuration` with response modality, voice, system instruction, tools, context-window compression, session resumption, manual VAD, output audio transcription
  - `Gemini::Live::MessageBuilder` for setup, clientContent, realtimeInput, activity start/end, and tool response messages
- Live API audio demos: `live_audio_demo.rb` (low-latency streaming), `live_audio_simple.rb`
- Manual VAD (Voice Activity Detection) support via `automatic_activity_detection: false`
- Live API Function Calling
  - `Session#send_realtime_text(text)` — universal text input via `realtimeInput.text`, required by newer Live models such as `gemini-3.1-flash-live-preview`
  - `MessageBuilder.realtime_text(text)` builder
  - Async (NON_BLOCKING) function call support: `MessageBuilder.tool_response` validates and normalizes the `scheduling` field (`INTERRUPT`, `WHEN_IDLE`, `SILENT`), accepted either inside the response payload or as a top-level shortcut
  - Demos: `live_function_calling_demo.rb` / `live_function_calling_demo_ja.rb`
- Embeddings API support (`embedContent` and `batchEmbedContents`)
  - `client.embeddings_api.create(input:, ...)` for single embeddings
  - `client.embeddings_api.batch_create(inputs:, ...)` for batch embeddings
  - `client.embed_content(input, ...)` shortcut that auto-routes Array inputs to batch
  - Optional parameters: `task_type` (RETRIEVAL_QUERY, RETRIEVAL_DOCUMENT, SEMANTIC_SIMILARITY, CLASSIFICATION, CLUSTERING, QUESTION_ANSWERING, FACT_VERIFICATION, CODE_RETRIEVAL_QUERY), `title` (RETRIEVAL_DOCUMENT only), `output_dimensionality`
  - Default model: `gemini-embedding-001`
- `Response` helpers for embeddings: `#embedding`, `#embeddings`, `#embedding_dimension`, `#embedding_response?`
- Demos: `embeddings_demo.rb` / `embeddings_demo_ja.rb`

### Notes
- Verified Live model compatibility on the `bidiGenerateContent` endpoint: only the native-audio variants and `gemini-3.1-flash-live-preview` are deployed today. The latter requires `realtimeInput.text` (i.e., `Session#send_realtime_text`) and `AUDIO` modality. The `gemini-2.5-flash-live-preview` model name listed in the public tools docs is not yet deployed.
- `MessageBuilder.realtime_input` (legacy `mediaChunks` path) is documented as deprecated by the upstream API; prefer `realtime_text` going forward.

## [1.0.0] - 2026-01-28

### Added
- Thinking feature support for Gemini 2.5 and Gemini 3 models
  - `thinking_budget` parameter for Gemini 2.5 (1-32768 tokens, -1 for dynamic, 0 to disable)
  - `thinking_level` parameter for Gemini 3 (:minimal, :low, :medium, :high)
- Thought Signatures support for Function Calling with Thinking
  - `FunctionCallingHelper.build_continuation` for automatic signature management
  - Response methods: `thought_signatures`, `first_thought_signature`, `has_thought_signature?`
- Response helper methods: `thoughts_token_count`, `model_version`, `gemini_3?`

## [0.1.7] - 2026-01-13

- Remove dotenv dependency

## [0.1.6] - 2025-12-11

- Add support for video understanding
  - Analyze local video files (Files API and inline data)
  - Analyze YouTube videos
  - Helper methods: describe, ask, extract_timestamps, analyze_segment
  - Support for MP4, MPEG, MOV, AVI, FLV, WebM, WMV, 3GPP formats
- Change default model to gemini-2.5-flash

## [0.1.5] - 2025-11-13

- Add support for URL Context tool
- Add simplified method for accessing grounding search sources

## [0.1.4] - 2025-11-08

- Add support for grounding search

## [0.1.3] - 2025-10-09

- Add support for multi-image input

## [0.1.2] - 2025-07-10

- Add function calling

## [0.1.1] - 2025-05-04

- Changed generate_contents to accept temperature parameter

## [0.1.0] - 2025-04-05

- Initial release
