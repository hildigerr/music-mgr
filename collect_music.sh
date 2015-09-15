#!/bin/bash

### Dependencies: mediainfo, lame

### Exit Status Table ###
# 0 == Success
# 1 == Invalid Parameter Flag
# 2 == Missing Directory

### TODO:
# Write/update tags including arbitrary tag fields.
# Add auto yes iscorrect option.
# Add option to convert without asking.
# Convert to ogg instead or also or as requested or whatever.
# Move converted wav files to workdir/old/wav or something like that.
# Make an option which will perform actions and clean up workdir.

usage() { echo "Usage: $0 [-v] [-s <source directory>] [-t <target directory>]" 1>&2; exit 1; }
nodir() { echo "ERROR: $1 does not exist or is not a directory." 1>&2; exit 2; }

### Variables ###
while getopts ":s:t:v" o; do
    case "${o}" in
        s) srcdir=${OPTARG} ;;
        t) dest=${OPTARG} ;;
        v) verbose=true ;;
        *) usage ;;
    esac
done
shift $((OPTIND-1))
workdir="${HOME}/.config/collect_music"
actsh="${workdir}/actions.sh"

### Default Values ###
if [ -z "${verbose}" ] ; then verbose=false ; fi
if [ -z "${srcdir}" ] ; then
    srcdir="`pwd`"
elif [ ! -d "${srcdir}" ] ; then
    nodir ${srcdir}
fi
if [ -z "${dest}" ] ; then
    dest="${HOME}/Music"
elif [ ! -d "${dest}" ] ; then
    nodir ${dest} #Or should we mkdir?
fi

if ${verbose} ; then
    echo "srcdir = ${srcdir}"
    echo "dest = ${dest}"
    echo "workdir = ${workdir}"
fi

if [ ! -d "${workdir}" ] ; then
    mkdir -vp "${workdir}"
fi
echo "#!/bin/bash" > "${actsh}"

# A temporary file is used to list all files in the source directory.
find "${srcdir}" -type f > ${workdir}/origin.list && echo
while read -r line || [[ -n ${line} ]]; do
    echo -e "\nFile: ${line}"

    ### Get Basic File Data ###
    filename=`basename "${line}"`
    data=`mediainfo "${line}"`
    format=`grep -m 1 "Format" <<<"${data}" | cut -d: -f 2- | sed 's/^ *//g'`

    ### Retrieve Media Tag Data ###
    if [ "${format}" = "Wave" ] ; then
        title=`basename "${line}" .wav`
        read -s -n 1 -p "Do you want to convert \"${line}\" to MP3 (y/n)? " doconvert < /dev/tty && echo #skip it if it has already been done
        if [ "${doconvert}" = 'y' ] || [ "${doconvert}" = 'Y' ] ; then
            lame -h -b128 "${line}" "${title}.mp3" && line="${title}.mp3"
        fi
    elif [ "${format}" = "MPEG Audio" ] || [ "${format}" = "OGG" ] ; then
        title=`grep -m 1 "Track name " <<<"${data}" | cut -d: -f 2- | sed 's/^ *//g'`
        artist=`grep -m 1 "Performer" <<<"${data}" | cut -d: -f 2- | sed 's/^ *//g'`
        album=`grep -m 1 "Album" <<<"${data}" | cut -d: -f 2- | sed 's/^ *//g'`
    else
        if ${verbose} ; then
            echo "[Unsupported file type, skipping...]"
        fi
        continue
    fi

    ### Verify Title ###
    if  [ -z "${title}" ] ; then
        title=${filename}
    fi
    while true ; do
        read -s -n 1 -p "Is \"${title}\" the correct song title (y/n)? " iscorrect < /dev/tty && echo
        if [ "${iscorrect}" = 'y' ] || [ "${iscorrect}" = 'Y' ] ; then
            break
        else
            read -p "Enter the song title: " title < /dev/tty
        fi
    done

    ### Verify Artist ###
    if [ -z "${artist}" ] ; then
        artist="Various Artists"
    fi
    while true ; do
        read -s -n 1 -p "Is \"${artist}\" the correct album artist (y/n)? " iscorrect < /dev/tty && echo
        if [ "${iscorrect}" = 'y' ] || [ "${iscorrect}" = 'Y' ] ; then
            break
        else
            read -p "Enter the album artist: " artist < /dev/tty
        fi
    done

    ### Verify Album ###
    if [ -z "${album}" ] ; then
        album="Unknown Album"
    fi
    while true ; do
        read -s -n 1 -p "Is \"${album}\" the correct album name (y/n)? " iscorrect < /dev/tty && echo
        if [ "${iscorrect}" = 'y' ] || [ "${iscorrect}" = 'Y' ] ; then
            break
        else
            read -p "Enter the album name: " album < /dev/tty
        fi
    done

    if ${verbose} ; then
        echo
        echo "title = ${title}"
        echo "artist = ${artist}"
        echo "album = ${album}"
    fi

    ### Setup Destination Directory Structure ###
    destdir="${dest}/${artist}/${album}"
    echo "destination = ${destdir}"
    if [ ! -d "${destdir}" ] ; then
        echo "mkdir -vp \"${destdir}\"" >> "${actsh}"
    fi

    echo "mv \"${line}\" \"${destdir}/${filename}\"" >> "${actsh}"

done < ${workdir}/origin.list
