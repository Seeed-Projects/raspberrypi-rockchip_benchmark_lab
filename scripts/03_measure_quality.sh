#!/usr/bin/env bash
set -Eeuo pipefail
[[ $# -eq 1 ]] || { echo 'Usage: bash scripts/03_measure_quality.sh output/your-video.mp4' >&2; exit 2; }
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC='/dev/shm/rkpi_real_4k_10s.nv12'
VIDEO="$1"
[[ -f "$VIDEO" ]] || { echo "Output file not found: $VIDEO" >&2; exit 1; }
[[ -f "$SRC" ]] || { echo 'RAM source missing; run 00_prepare_input.sh' >&2; exit 1; }
printf '%s  %s\n' 'd1e3403d6886a5472c7261dfe07a4149b941d1d7bdfa92d46f181dff381f5fd7' "$SRC" | sha256sum -c -
mkdir -p "$ROOT/logs"
NAME="$(basename "$VIDEO" .mp4)"
LOG="$ROOT/logs/quality_${NAME}.log"
ffmpeg -hide_banner -nostdin \
  -f rawvideo -pixel_format nv12 -video_size 3840x2160 -framerate 30 -i "$SRC" \
  -i "$VIDEO" \
  -filter_complex '[0:v]format=yuv420p,settb=AVTB,setpts=PTS-STARTPTS[ref];[1:v]format=yuv420p,settb=AVTB,setpts=PTS-STARTPTS[dist];[dist][ref]ssim=shortest=1:repeatlast=0[out]' \
  -map '[out]' -frames:v 300 -an -f null - > "$LOG" 2>&1 || { tail -n 40 "$LOG"; exit 1; }
echo "===== SSIM: $VIDEO ====="
grep 'SSIM Y:' "$LOG" | tail -n 1
echo '===== Output ====='
ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=bit_rate,nb_read_frames \
  -of default=noprint_wrappers=1 "$VIDEO"
