## [Unreleased]

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
