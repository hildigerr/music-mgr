#!/bin/bash

MAGIC_TAG0="#!$0"
MAGIC_TAG1="#!$(basename $0)"
MAGIC_TAG2="#!/usr/bin/env $(basename "$0")"

toggle_pause() {
  if [ -n "${ppid}" ] && ps -p "${ppid}" >/dev/null; then
    if ps -o state= -p "${ppid}" | grep -q "T"; then
      kill -CONT "${ppid}"
    else
      kill -STOP "${ppid}"
    fi
  fi
}

trap toggle_pause SIGUSR1

if [ $# -eq 0 ]; then exec "$0" "$HOME/Music/"; fi

for each in "$@"; do
  unset ppid
  if [ -d "${each}" ] ; then
    echo "Generating Random Playlist: \"${each}\""
    find "${each}" -type f -print0 | sort -Rz | xargs -0 "$0"
  elif [ -f "${each}" ] ; then
    case $(file --mime-type -b "${each}") in
      text/plain)
        headline=$(head -n 1 "${each}" 2>/dev/null)
        if [ "$headline" != "$MAGIC_TAG0" ] && \
           [ "$headline" != "$MAGIC_TAG1" ] && \
           [ "$headline" != "$MAGIC_TAG2" ]; then
           continue
        fi
        echo "Playing Playlist: \"${each}\""
        tail -n +2 "${each}" | xargs --delimiter "\n" "$0" ;;
      image/gif) ;&
      image/jpeg) ;&
      image/png)
        chafa "${each}" 2>/dev/null ;; #XXX
      audio/midi)
        echo -e "\n${each}:\n"
        fluidsynth -i "${each}" 2>/dev/null &
        ppid=$!
        while kill -0 "${ppid}" 2>/dev/null; do
          wait "${ppid}" 2>/dev/null
        done
      ;;
      audio/flac) ;&
      audio/mpeg) ;&
      audio/ogg) ;&
      audio/x-aiff) ;&
      audio/x-m4a) ;&
      audio/x-wav)
        play "${each}" &
        ppid=$!
        while kill -0 "${ppid}" 2>/dev/null; do
          wait "${ppid}" 2>/dev/null
        done
      ;;
      audio/x-mod)
        echo -e "\n${each}:\n"
        cvlc --play-and-exit "${each}" &
        ppid=$!
        while kill -0 "${ppid}" 2>/dev/null; do
          wait "${ppid}" 2>/dev/null
        done
      ;;
      *) echo "Unhandled Filetype: \"${each}\"" ;;
    esac
  else
    echo -e "\n${each}:\nTrying..."
    cvlc --play-and-exit "${each}" &
    ppid=$!
    while kill -0 "${ppid}" 2>/dev/null; do
      wait "${ppid}" 2>/dev/null
    done
  fi
done
