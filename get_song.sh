#!/bin/bash

#v0
cd $HOME/Downloads/youtube-dl
xargs -n1 ./youtube-dl < todo.list

for file in *.mp4 ; do
  name=`basename "$file" .mp4`
  echo $name
  mplayer -vc dummy -vo null -ao pcm:file="$name.wav" "$file"
  lame -h -b128 "$name.wav" "$name.mp3"
  rm -v "$name.wav"
done

