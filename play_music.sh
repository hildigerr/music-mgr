#!/bin/bash

if [ $# -eq 0 ]; then $0 "$HOME/Music/"; fi

for each in "$@"; do
  if [ -d "${each}" ] ; then
    echo "Generating Random Playlist: \"${each}\""
    find "${each}" -type f -print0 | sort -Rz | xargs -0 $0
  elif [ -f "${each}" ] ; then
    case $(file --mime-type -b "${each}") in
      text/plain)
        echo "Playing Playlist: \"${each}\""
        xargs -0 --arg-file "${each}" --delimiter "\n" $0 ;;
      image/gif) ;&
      image/jpeg) ;&
      image/png)
        chafa "${each}" 2>/dev/null ;; #XXX
      audio/flac) ;&
      audio/mpeg) ;&
      audio/ogg) ;&
      audio/x-aiff) ;&
      audio/x-m4a) ;&
      audio/x-wav)
        play "${each}"
      ;;
      *) echo "Unhandled Filetype: \"${each}\"" ;;
    esac
  fi
done
