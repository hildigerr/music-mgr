#!/bin/bash

### Dependencies: id3v2

### Exit Status Table ###
# 0 == Success
# 1 == Invalid Parameter Flag

### TODO:
# Write/update ogg tags with vorbis-tools (ogginfo,vorbiscomment)
# Edit arbitrary tag fields.
# Add auto yes iscorrect option.

askyn() { read -s -n 1 -p "$1 (y/n)? " $2 </dev/tty && echo; }
usage() { echo "Usage: $0 [-v] [-t <target directory>] FILE..." 1>&2; exit 1; }

### Variables ###
while getopts ":t:v" o; do
    case "${o}" in
        t) dest=${OPTARG} ;;
        v) verbose=true ;;
        *) usage ;;
    esac
done
shift $((OPTIND-1))

### Default Values ###
if [ -z "${verbose}" ] ; then verbose=false ; fi
if [ -z "${dest}" ] ; then dest="${HOME}/Music" ; fi

if ${verbose} ; then
    echo "dest = ${dest}"
fi

for line in "$@"; do
    echo -e "\nFile: ${line}"

    ### Get Basic File Data ###
    filename=`basename "${line}"`
    format=`echo "${filename}" | tr . \\\n | tail -n1 | tr "[:lower:]" "[:upper:]"`

    ### Retrieve Media Tag Data ###
    if [ "${format}" = "WAV" ] ; then
        title=`basename "${line}" .wav`
        title=`basename "${title}" .WAV`
    elif [ "${format}" = "MP3" ] ; then
        id3v2 -C "${line}"
        id3v2 -s "${line}"
        data=`id3v2 -l "${line}"`
        title=`grep -m 1 "^TIT2 " <<<"${data}" | cut -d: -f 2- | sed 's/^ *//g'`
        artist=`grep -m 1 "^TPE1" <<<"${data}" | cut -d: -f 2- | sed 's/^ *//g'`
        album=`grep -m 1 "^TALB" <<<"${data}" | cut -d: -f 2- | sed 's/^ *//g'`
        genre=`grep -m 1 "^TCON" <<<"${data}" | cut -d: -f 2- | cut -d\  -f 2`
    else
        if ${verbose} ; then
            echo "[Unsupported file type, skipping...]"
        fi
        continue
    fi

    if  [ -z "${title}" ] ; then
        title=${filename}
        updatetag=true
    fi
    if [ -z "${artist}" ] || [ "${artist}" = "Various" ] ; then
        artist="Various Artists"
        updatetag=true
    fi
    if [ -z "${album}" ] ; then
        album="Unknown Album"
        updatetag=true
    fi

    ### Prepare to Update Tags ###
    echo "title = ${title}"
    echo "artist = ${artist}"
    echo "album = ${album}"
    echo "genre = ${genre}"
    askyn "Do you trust this file to be tagged correctly" tagok
    if [ "${tagok}" = 'n' ] || [ "${tagok}" = 'N' ] ; then
        updatetag=true

    ### Verify Title ###
        while true ; do
            askyn "Is \"${title}\" the correct song title" iscorrect
            if [ "${iscorrect}" = 'y' ] || [ "${iscorrect}" = 'Y' ] ; then
                break
            else
                read -p "Enter the song title: " title < /dev/tty
            fi
        done

    ### Verify Artist ###
        askyn "Is \"${artist}\" the correct album artist" iscorrect
        if [ "${iscorrect}" = 'n' ] || [ "${iscorrect}" = 'N' ] ; then
            if ${verbose} ; then
                echo "Guessing artist based on path..."
            fi
            artist=`echo ${line} | rev | cut -d/ -f 3 | rev`

            while true ; do
                askyn "Is \"${artist}\" the correct album artist" iscorrect
                if [ "${iscorrect}" = 'y' ] || [ "${iscorrect}" = 'Y' ] ; then
                    break
                else
                    read -p "Enter the album artist: " artist < /dev/tty
                fi
            done
        fi

    ### Verify Album ###
        while true ; do
            askyn "Is \"${album}\" the correct album name" iscorrect
            if [ "${iscorrect}" = 'y' ] || [ "${iscorrect}" = 'Y' ] ; then
                break
            else
                read -p "Enter the album name: " album < /dev/tty
            fi
        done
    fi

    ### Update Tags ###
    if [ "${format}" = "MP3" ] && [ ${updatetag} ] ; then
        if ${verbose} ; then
            echo
            echo "title = ${title}"
            echo "artist = ${artist}"
            echo "album = ${album}"
        fi
        askyn "Ok to write the tags" confirm
        if [ "${confirm}" = 'y' ] || [ "${confirm}" = 'Y' ] ; then
            id3v2 -t "${title}" -a "${artist}"  -A "${album}""${line}"
        fi
    fi

    ### Setup Destination Directory Structure ###
    destdir="${dest}/${artist}/${album}"
    while true ; do
        echo "destination = \"${destdir}\""
        askyn "Is this the desired destination" confirm
        if [ "${confirm}" = 'y' ] || [ "${confirm}" = 'Y' ] ; then
            break
        else
            read -p "Enter the desired destination: " destdir < /dev/tty
        fi
    done
    if [ ! -d "${destdir}" ] ; then
        mkdir -vp "${destdir}"
    fi

    ### Move The File to its Final Destination ###
    if [ ! -e "${destdir}/${filename}" ] ; then
        mv "${line}" "${destdir}/${filename}"
    else
        askyn "Do you wish to overwrite the existing file" replace
        if [ "${replace}" = 'y' ] || [ "${replace}" = 'Y' ] ; then
            mv "${line}" "${destdir}/${filename}"
        fi
    fi

done

