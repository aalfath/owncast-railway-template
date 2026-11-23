#!/bin/sh
# ffmpeg wrapper for Owncast on Railway.
#
# Owncast runs ffmpeg without a thread limit, so x264 sizes its thread pool from
# the host's CPU count (often 32 or more), not the container's limit. On a small
# Railway plan that wastes memory and can get the service OOM-killed. This
# wrapper adds "-threads N" (N = the container's CPU limit, or
# OWNCAST_FFMPEG_THREADS) right before the output of Owncast's live transcode.
# Every other call (version check, thumbnails) goes through unchanged.
FFMPEG=/usr/bin/ffmpeg

case " $* " in
  *" -hls_segment_filename "*) ;;
  *) exec "$FFMPEG" "$@" ;;
esac

threads="${OWNCAST_FFMPEG_THREADS:-}"
if [ -z "$threads" ]; then
  if [ -r /sys/fs/cgroup/cpu.max ]; then
    read -r quota period < /sys/fs/cgroup/cpu.max || true
    if [ "${quota:-max}" != "max" ] && [ "${period:-0}" -gt 0 ] 2>/dev/null; then
      threads=$(( (quota + period - 1) / period ))
    fi
  fi
  [ -n "$threads" ] || threads=$(nproc 2>/dev/null || echo 2)
  [ "$threads" -ge 1 ] 2>/dev/null || threads=1
  [ "$threads" -le 8 ] || threads=8
fi

# Rebuild the argument list with "-threads N" before the last argument (the
# HLS playlist output). The for loop expands "$@" once, so "set --" is safe.
n=$#
i=0
for arg do
  i=$((i + 1))
  [ "$i" -eq 1 ] && set --
  [ "$i" -eq "$n" ] && set -- "$@" -threads "$threads"
  set -- "$@" "$arg"
done
exec "$FFMPEG" "$@"
