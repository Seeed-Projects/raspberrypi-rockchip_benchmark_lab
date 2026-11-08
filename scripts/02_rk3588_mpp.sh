#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC='/dev/shm/rkpi_real_4k_10s.nv12'
EXPECTED_SHA='d1e3403d6886a5472c7261dfe07a4149b941d1d7bdfa92d46f181dff381f5fd7'
mkdir -p "$ROOT/output" "$ROOT/logs"
[[ -f "$SRC" ]] || { echo 'RAM source missing; run 00_prepare_input.sh' >&2; exit 1; }
printf '%s  %s\n' "$EXPECTED_SHA" "$SRC" | sha256sum -c -
command -v gst-launch-1.0 >/dev/null || { echo 'gst-launch-1.0 missing' >&2; exit 1; }
command -v mpph264enc >/dev/null 2>&1 || true # GStreamer element, not a shell executable

for i in 1 2 3; do
  OUT="$ROOT/output/mpp_rk3588_run${i}.mp4"
  LOG="$ROOT/logs/mpp_rk3588_run${i}.log"
  echo "===== RK3588 MPP RAM run ${i} ====="
  sudo /usr/bin/time -v gst-launch-1.0 -e \
    filesrc location="$SRC" ! \
    rawvideoparse format=nv12 width=3840 height=2160 framerate=30/1 ! \
    mpph264enc rc-mode=cbr bps=10000000 gop=60 ! \
    h264parse ! mp4mux ! filesink location="$OUT" > "$LOG" 2>&1 || {
      tail -n 40 "$LOG"; exit 1;
    }
  FRAMES="$(ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of csv=p=0 "$OUT")"
  [[ "$FRAMES" == '300' ]] || { echo "Wrong frame count: $FRAMES" >&2; exit 1; }
  grep -E 'Execution ended|Elapsed|Percent of CPU|Exit status' "$LOG" | tail -n 6
  ffprobe -v error -select_streams v:0 -show_entries stream=bit_rate,nb_frames -of default=noprint_wrappers=1 "$OUT"
  (( i < 3 )) && sleep 5 || true
done
