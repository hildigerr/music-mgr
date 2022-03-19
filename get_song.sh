#!/bin/bash

#v0
cd $HOME/Downloads/youtube-dl
xargs -n1 ./youtube-dl < todo.list

# This is the command that I came up with first. However, it does not convert the raw audio to mp3
ls *.mp4 | awk -F'\n' '{print "--nogui --load \"" $1 "\" --save-raw-audio \"" $1 ".mp3\" \"" $1 "\" --quit" }' | xargs -n1 avidemux_cli

