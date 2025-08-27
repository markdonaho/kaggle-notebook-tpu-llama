#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path


def find_all_indices(lines, predicate):
    return [i for i, line in enumerate(lines) if predicate(line)]


def strip_trailing_preamble(summary_lines):
    # Remove trailing lines that belong to the next block preamble (e.g., zoomXX, Transcript:, raw URL)
    patterns = [
        re.compile(r"^\s*$"),
        re.compile(r"^\s*zoom\d+\s*$", re.IGNORECASE),
        re.compile(r"^\s*Transcript:\s*$", re.IGNORECASE),
        re.compile(r"^https?://\S+_transcript\.txt\s*$", re.IGNORECASE),
    ]
    end = len(summary_lines)
    while end > 0:
        line = summary_lines[end - 1]
        if any(p.match(line) for p in patterns):
            end -= 1
            continue
        break
    return summary_lines[:end]


def strip_leading_blanks(lines):
    start = 0
    while start < len(lines) and lines[start].strip() == "":
        start += 1
    return lines[start:]


def parse_pairs(all_text: str):
    lines = all_text.splitlines()
    pairs = []

    # Indices of all 'Generated on:' lines which mark the end of a transcript block
    gen_on_indices = find_all_indices(lines, lambda ln: ln.strip().startswith("Generated on:"))

    # Quick helpers
    def find_prev_transcription_header(before_index: int):
        for i in range(before_index - 1, -1, -1):
            if lines[i].strip().startswith("TRANSCRIPTION WITH SPEAKER DIARIZATION"):
                return i
        return None

    def find_next_summary(after_index: int):
        for i in range(after_index + 1, len(lines)):
            if lines[i].strip().startswith("Summary:"):
                return i
        return None

    for pos, g_idx in enumerate(gen_on_indices):
        # Find the transcription header before this 'Generated on:'
        t_header_idx = find_prev_transcription_header(g_idx)
        if t_header_idx is None:
            continue  # cannot safely parse this block

        # Try to capture a URL immediately preceding the header (commonly provided for each transcript)
        url_line = None
        for i in range(max(0, t_header_idx - 6), t_header_idx):
            candidate = lines[i].strip()
            if re.match(r"^https?://\\S+", candidate, flags=re.IGNORECASE):
                url_line = candidate
        
        # Transcript starts two lines after the header (skip the surrounding '====' line)
        transcript_start = min(t_header_idx + 2, len(lines))
        transcript_end = max(0, g_idx)  # exclusive end
        transcript_lines = lines[transcript_start:transcript_end]

        # Find the matching 'Summary:' after this 'Generated on:'
        s_idx = find_next_summary(g_idx)
        if s_idx is None:
            continue

        # Determine where this summary ends: just before the next 'Generated on:' or EOF
        next_g_idx = gen_on_indices[pos + 1] if (pos + 1) < len(gen_on_indices) else len(lines)
        summary_lines = lines[s_idx + 1:next_g_idx]

        # Tidy transcript and summary
        transcript_lines = strip_leading_blanks(transcript_lines)
        summary_lines = strip_trailing_preamble(summary_lines)
        summary_lines = strip_leading_blanks(summary_lines)

        transcript_body = "\n".join(transcript_lines).strip()
        if url_line:
            transcript = f"{url_line}\n\n{transcript_body}".strip()
        else:
            transcript = transcript_body
        summary = "\n".join(summary_lines).strip()

        if transcript and summary:
            pairs.append({"transcript": transcript, "summary": summary})

    return pairs


def main():
    if len(sys.argv) != 3:
        print("Usage: build_training_json.py <input_txt> <output_json>")
        sys.exit(2)

    input_path = Path(sys.argv[1]).expanduser().resolve()
    output_path = Path(sys.argv[2]).expanduser().resolve()

    text = input_path.read_text(encoding="utf-8", errors="ignore")
    pairs = parse_pairs(text)

    # Write JSON array
    output_path.write_text(json.dumps(pairs, ensure_ascii=False, indent=2), encoding="utf-8")

    print(f"Wrote {len(pairs)} pairs to {output_path}")


if __name__ == "__main__":
    main()


