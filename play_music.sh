#!/bin/bash

APP_NAME="$(basename "$0")"
MAGIC_TAG0="#!$0"
MAGIC_TAG1="#!${APP_NAME}"
MAGIC_TAG2="#!/usr/bin/env ${APP_NAME}"
NSID_F="${XDG_RUNTIME_DIR:-/dev/shm}/${APP_NAME}_nsid.$UID"

notify() {
  local nsid=$(cat "${NSID_F}" 2>/dev/null)
  nsid="$(
    notify-send --app-name="${APP_NAME}" "$@" \
      --icon=${icon:-applications-multimedia} \
      --print-id $( if [ -n "${nsid}" ]; then
          printf "%s" "--replace-id=${nsid}"
        fi) \
      "${status:-Loading}" "${message:-Please Wait...}" 2>/dev/null
  )"
  echo "${nsid}" > "${NSID_F}"
}

monitor() {
  icon=media-playback-start
  status=Playing
  notify
  while kill -0 "${ppid}" 2>/dev/null; do
    wait "${ppid}" 2>/dev/null
  done
}

cleanup() {
  icon=media-playback-stop
  status=Aborted
  notify --transient
  trap - TERM
  kill -TERM 0 2>/dev/null
  exit 0
}

toggle_pause() {
  if [ -n "${ppid}" ] && ps -p "${ppid}" >/dev/null; then
    if ps -o state= -p "${ppid}" | grep -q "T"; then
      kill -CONT "${ppid}"
      icon=media-playback-start
      status=Playing
      notify
    else
      kill -STOP "${ppid}"
      icon=media-playback-pause
      status=Paused
      notify
    fi
  fi
}

skip() {
  if [ -n "${ppid}" ] && ps -p "${ppid}" >/dev/null; then
    kill "${ppid}" 2>/dev/null
  fi
}

trap cleanup TERM
trap toggle_pause SIGUSR1
trap skip SIGUSR2

if [ $# -eq 0 ]; then exec "$0" "$HOME/Music/"; fi

for each in "$@"; do
  unset icon status message mpid ppid
  if [ -d "${each}" ] ; then
    echo "Generating Random Playlist: \"${each}\""
    trap - TERM
    find "${each}" -type f -print0 | sort -Rz | xargs -0 "$0"
    trap cleanup TERM
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
        trap - TERM
        tail -n +2 "${each}" | xargs --delimiter "\n" "$0"
        trap cleanup TERM
      ;;
      image/gif) ;&
      image/jpeg) ;&
      image/png)
        chafa "${each}" 2>/dev/null ;; #XXX
      audio/midi)
        echo -e "\n${each}:\n"
        fluidsynth -i "${each}" 2>/dev/null &
        ppid=$!
        monitor
      ;;
      audio/flac) ;&
      audio/mpeg) ;&
      audio/ogg) ;&
      audio/x-aiff) ;&
      audio/x-m4a) ;&
      audio/x-wav)
        play "${each}" &
        ppid=$!
        monitor
      ;;
      video/x-ms-asf) ;&
      audio/x-mod)
        echo -e "\n${each}:\n"
        cvlc --play-and-exit "${each}" &
        ppid=$!
        monitor
      ;;
      *)
        echo -e "\n${each}:\n"
        echo -e "\tUnhandled Filetype: $(file --mime-type -b "${each}")"
      ;;
    esac
  else
    if [ "${each%${each#?}}" = "#" ]; then continue; fi
    echo -en "\n${each}:\n\n  Trying: "
    metaint=$(
      curl -sI -H "Icy-MetaData: 1" "$each" |
      awk -F': *' 'tolower($1)=="icy-metaint"{gsub("\r","",$2); print $2}'
    )
    if [ -n "$metaint" ] && [ "$metaint" -gt 0 ]; then
      (
        StreamTitle=""
        while true; do
          StreamTitleNow=$(ffprobe -v quiet \
            -show_entries format_tags=StreamTitle \
            -of default=nw=1:nk=1 "$each")
          if [ -n "$StreamTitleNow" ] && \
             [ "$StreamTitleNow" != "$StreamTitle" ]; then
             echo "    $StreamTitleNow"
             StreamTitle="$StreamTitleNow"
          fi
          sleep 15
        done
      ) &
      mpid=$!
    fi
    cvlc --play-and-exit "${each}" &
    ppid=$!
    monitor
    [ -n "$mpid" ] && kill "$mpid" 2>/dev/null
  fi
done
status=Ended
message="Thanks for listening!"
notify --transient
