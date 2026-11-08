#!/usr/bin/env bash
set -Eeuo pipefail
[[ $# -eq 1 && ( "$1" == 'pi5' || "$1" == 'rk3588' ) ]] || {
  echo 'Usage: bash scripts/01_cpu_encode.sh pi5|rk3588' >&2; exit 2;
}
DEVICE="$1"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC='/dev/shm/rkpi_real_4k_10s.nv12'
EXPECTED_SHA='d1e3403d6886a5472c7261dfe07a4149b941d1d7bdfa92d46f181dff381f5fd7'
mkdir -p "$ROOT/output" "$ROOT/logs"
[[ -f "$SRC" ]] || { echo 'RAM source missing; run 00_prepare_input.sh' >&2; exit 1; }
printf '%s  %s\n' "$EXPECTED_SHA" "$SRC" | sha256sum -c -

for i in 1 2 3; do
  OUT="$ROOT/output/cpu_${DEVICE}_run${i}.mp4"
  LOG="$ROOT/logs/cpu_${DEVICE}_run${i}.log"
  echo "===== ${DEVICE} libx264 RAM run ${i} ====="
  /usr/bin/time -v ffmpeg -hide_banner -nostdin -benchmark \
    -f rawvideo -pixel_format nv12 -video_size 3840x2160 -framerate 30 -i "$SRC" \
    -an -c:v libx264 -preset veryfast -b:v 10M -maxrate 10M -bufsize 20M \
    -g 60 -threads 4 -pix_fmt yuv420p -y "$OUT" > "$LOG" 2>&1 || {
      tail -n 35 "$LOG"; exit 1;
    }
  ffprobe -v error -count_frames -select_streams v:0 \
    -show_entries stream=nb_read_frames,bit_rate -of default=noprint_wrappers=1 "$OUT"
  grep -E 'bench:|Elapsed|Percent of CPU|Exit status' "$LOG" | tail -n 6
  (( i < 3 )) && sleep 5 || true
done
