#!/bin/bash

#v1
cd $HOME/Downloads/youtube-dl
./youtube-dl https://www.youtube.com/watch?v=$1
origin=`ls *"$1"* | tail -n1`
ext=`echo "$origin" | tr . \\\n | tail -n1`
name=`basename "$origin" "$ext"`
ffmpeg -i "$origin" "${name}mp3" && rm "$origin"

