#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$ROOT/input" "$ROOT/output" "$ROOT/logs"
ZIP="$ROOT/input/bbb_sunflower_2160p_30fps_normal.mp4.zip"
MP4="$ROOT/input/real_4k_source.mp4"
RAW="$ROOT/input/real_4k_10s.nv12"
RAM='/dev/shm/rkpi_real_4k_10s.nv12'
URL='https://download.blender.org/demo/movies/BBB/bbb_sunflower_2160p_30fps_normal.mp4.zip'
SOURCE_SHA='37f0ff251a606c2dcfa26c19fe6bf843234b4e7a8889cfab50bc26f644e55520'
RAW_SHA='d1e3403d6886a5472c7261dfe07a4149b941d1d7bdfa92d46f181dff381f5fd7'
RAW_BYTES=3732480000

for cmd in wget unzip sha256sum ffmpeg stat df cp; do command -v "$cmd" >/dev/null || { echo "Missing command: $cmd" >&2; exit 1; }; done

if [[ ! -f "$MP4" ]]; then
  echo '[1/4] Downloading Blender Foundation source (ZIP)...'
  wget -c "$URL" -O "$ZIP"
  unzip -tq "$ZIP"
  unzip -p "$ZIP" bbb_sunflower_2160p_30fps_normal.mp4 > "$MP4"
fi

echo '[2/4] Verifying source MP4 SHA-256...'
printf '%s  %s\n' "$SOURCE_SHA" "$MP4" | sha256sum -c -

if [[ ! -f "$RAW" ]]; then
  echo '[3/4] Extracting exactly 300 4K NV12 frames (this creates 3.73 GB)...'
  ffmpeg -hide_banner -nostdin -v warning -ss 00:01:00 -i "$MP4" \
    -map 0:v:0 -an -vf 'fps=30,scale=3840:2160,format=nv12' \
    -frames:v 300 -pix_fmt nv12 -f rawvideo -y "$RAW"
fi
[[ "$(stat -c %s "$RAW")" -eq "$RAW_BYTES" ]] || { echo 'Unexpected NV12 byte count' >&2; exit 1; }
printf '%s  %s\n' "$RAW_SHA" "$RAW" | sha256sum -c -

echo '[4/4] Copying identical NV12 into /dev/shm...'
FREE="$(df -B1 --output=avail /dev/shm | tail -n 1 | tr -d ' ')"
[[ "$FREE" -ge "$RAW_BYTES" ]] || { echo "Not enough free /dev/shm space: need $RAW_BYTES bytes" >&2; exit 1; }
cp "$RAW" "$RAM"
printf '%s  %s\n' "$RAW_SHA" "$RAM" | sha256sum -c -
echo "Ready: $RAM"
