#!/bin/bash

#v2
cd $HOME/Downloads/youtube-dl
./youtube-dl -F https://www.youtube.com/watch?v=$1
read -p "Select format code: " num </dev/tty && echo
./youtube-dl -f $num https://www.youtube.com/watch?v=$1
origin=`ls *"$1"* | tail -n1`
ext=`echo "$origin" | tr . \\\n | tail -n1`
name=`basename "$origin" "$ext"`
ffmpeg -i "$origin" "${name}mp3"
read -s -n 1 -p "Keep \"$origin\" (y/n)? " yn </dev/tty && echo
if [ "${yn}" = 'n' ] || [ "${yn}" = 'N' ] ; then rm "$origin"; fi

