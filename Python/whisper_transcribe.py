#!/usr/bin/env python3
"""
Whisper Transcription Script for OneOnOne
Transcribes audio files using OpenAI's Whisper model

Created by Jordan Koch on 2026-02-02.
Copyright © 2026 Jordan Koch. All rights reserved.
"""

import sys
import json
import os

def transcribe_audio(audio_path: str) -> dict:
    """
    Transcribe an audio file using Whisper.

    Args:
        audio_path: Path to the audio file to transcribe

    Returns:
        Dictionary containing transcription results
    """
    try:
        import whisper
    except ImportError:
        # Fallback: try mlx-whisper if available
        try:
            from mlx_whisper import transcribe
            result = transcribe(audio_path)
            return {
                "text": result.get("text", ""),
                "segments": result.get("segments", []),
                "language": result.get("language", "en")
            }
        except ImportError:
            return {
                "error": "Whisper not installed. Install with: pip install openai-whisper or pip install mlx-whisper",
                "text": "",
                "segments": [],
                "language": "en"
            }

    # Load the model (use base for speed, or large-v3 for accuracy)
    model_name = os.environ.get("WHISPER_MODEL", "base")

    try:
        model = whisper.load_model(model_name)
    except Exception as e:
        return {
            "error": f"Failed to load Whisper model: {str(e)}",
            "text": "",
            "segments": [],
            "language": "en"
        }

    # Transcribe
    try:
        result = model.transcribe(
            audio_path,
            language=None,  # Auto-detect language
            task="transcribe",
            verbose=False
        )

        # Format segments
        segments = []
        for segment in result.get("segments", []):
            segments.append({
                "text": segment.get("text", "").strip(),
                "start": segment.get("start", 0),
                "end": segment.get("end", 0),
                "confidence": segment.get("no_speech_prob", 0)
            })

        return {
            "text": result.get("text", "").strip(),
            "segments": segments,
            "language": result.get("language", "en")
        }

    except Exception as e:
        return {
            "error": f"Transcription failed: {str(e)}",
            "text": "",
            "segments": [],
            "language": "en"
        }


def main():
    if len(sys.argv) < 2:
        print(json.dumps({
            "error": "Usage: whisper_transcribe.py <audio_file>",
            "text": "",
            "segments": [],
            "language": "en"
        }))
        sys.exit(1)

    audio_path = sys.argv[1]

    if not os.path.exists(audio_path):
        print(json.dumps({
            "error": f"File not found: {audio_path}",
            "text": "",
            "segments": [],
            "language": "en"
        }))
        sys.exit(1)

    result = transcribe_audio(audio_path)
    print(json.dumps(result))


if __name__ == "__main__":
    main()
