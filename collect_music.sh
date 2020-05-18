#!/bin/bash

### Exit Status Table ###
# 0 == Success
# 1 == Invalid Parameter Flag

### TODO:
# Edit arbitrary tag fields.
# Remove/update deprecated tag fields. https://id3.org/id3v2.4.0-changes
# play song only optionally
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
    updatetag=false
    echo -e "\nFile: ${line}"

    ### Get Basic File Data ###
    filename=`basename "${line}"`
    format=`echo "${filename}" | tr . \\\n | tail -n1 | tr "[:lower:]" "[:upper:]"`

    ### Retrieve Media Tag Data ###
    if [ "${format}" = "WAV" ] ; then
        title=`basename "${line}" .wav`
        title=`basename "${title}" .WAV`
    elif [ "${format}" = "MP3" ] || [ "${format}" = "OGG" ] ; then
        data=`mtag -l= "${line}"`
        title=`grep -i -m 1 "^TITLE" <<<"${data}" | cut -d= -f 2`
        artist=`grep -i -m 1 "^ARTIST" <<<"${data}" | cut -d= -f 2`
        album=`grep -i -m 1 "^ALBUM" <<<"${data}" | cut -d= -f 2`
        genre=`grep -i -m 1 "^GENRE" <<<"${data}" | cut -d= -f 2`
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
    if [ -z "${genre}" ] ; then
        genre="Other"
        updatetag=true
    fi

    ### Prepare to Update Tags ###
    play -q "${line}" &
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

    ### Verify Genre ###
        while true ; do
            askyn "Is \"${genre}\" the correct artist genre" iscorrect
            if [ "${iscorrect}" = 'y' ] || [ "${iscorrect}" = 'Y' ] ; then
                break
            else
                read -p "Enter the artist genre: " genre < /dev/tty
            fi
        done

    fi

    ### Update Tags ###
    if ${updatetag} ; then
        if ${verbose} ; then
            echo
            echo "title = ${title}"
            echo "artist = ${artist}"
            echo "album = ${album}"
            echo "genre = ${genre}"
        fi
        askyn "Ok to write the tags" confirm
        if [ "${confirm}" = 'y' ] || [ "${confirm}" = 'Y' ] ; then
            if [ "${format}" = "MP3" ] || [ "${format}" = "OGG" ] ; then
                echo "Writing the tags..."
                mtag -t "${title}" -a "${artist}" -A "${album}" -g "${genre}" "${line}"
                case $? in
                    0) echo "Ok" ;;
                    1) echo "ERROR: Invalid Option!" ;;
                    2) echo "ERROR: Filename Invalid!" ;;
                    3) echo "ERROR: File Invalid!" ;;
                    4) echo "ERROR: Tag Empty!" ;;
                    5) echo "ERROR: File Not Saved!" ;;
                esac
            fi
        fi
    fi

    ### Setup Destination Directory Structure ###
    destdir="${dest}/${genre}/${artist}/${album}"
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
    elif [ "${line}" != "${destdir}/${filename}" ] ; then
        askyn "Do you wish to overwrite the existing file" replace
        if [ "${replace}" = 'y' ] || [ "${replace}" = 'Y' ] ; then
            mv "${line}" "${destdir}/${filename}"
        fi
    fi

    killall play
done

