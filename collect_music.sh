#!/bin/bash

### Dependencies: mediainfo, id3

### Exit Status Table ###
# 0 == Success
# 1 == Invalid Parameter Flag
# 2 == Missing Directory

### TODO:
# Edit arbitrary tag fields.
# Add auto yes iscorrect option.
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

    ### Prepare to Update Tags ###
    echo "title = ${title}"
    echo "artist = ${artist}"
    echo "album = ${album}"
    read -s -n 1 -p "Do you trust this file to be tagged correctly (y/n)? " tagok < /dev/tty && echo
    if [ "${tagok}" = 'y' ] || [ "${tagok}" = 'Y' ] ; then
        verifytag=false
    else
        read -s -n 1 -p "Is the problem that the album artist should be \"Various Artists\" (y/n)? " quickfix < /dev/tty && echo
        if [ "${quickfix}" = 'y' ] || [ "${quickfix}" = 'Y' ] ; then
            artist="Various Artists"
            verifytag=false
        else
            verifytag=true
        fi
    fi

    ### Verify Title ###
    if  [ -z "${title}" ] ; then
        title=${filename}
        pretagged=false
    else
        pretagged=true
    fi
    if [ ${verifytag} = true ] ; then
        while true ; do
            read -s -n 1 -p "Is \"${title}\" the correct song title (y/n)? " iscorrect < /dev/tty && echo
            if [ "${iscorrect}" = 'y' ] || [ "${iscorrect}" = 'Y' ] ; then
                break
            else
                if ${pretagged} ; then
                    read -s -n 1 -p "Do you wish to overwrite the current tag infomration (y/n)? " retagging < /dev/tty && echo
                    if [ "${retagging}" = 'y' ] || [ "${retagging}" = 'Y' ] ; then
                        pretagged=false
                    fi
                fi
                read -p "Enter the song title: " title < /dev/tty
            fi
        done
    fi
    if [ ! "${format}" = "Wave" ] && [ ! ${pretagged} ] ; then
        echo "id3 -t \"${title}\" \"${line}\"" >> "${actsh}"
    fi

    ### Verify Artist ###
    if [ -z "${artist}" ] ; then
        if ${verbose} ; then
            echo "Guessing artist based on path..."
        fi
        artist=`echo ${line} | rev | cut -d/ -f 3 | rev`
        pretagged=false
    else
        pretagged=true
    fi
    if [ -z "${artist}" ] || [ "${artist}" = "Various" ] ; then
        artist="Various Artists"
        pretagged=false
    fi
    if [ ${verifytag} = true ] ; then
        while true ; do
            read -s -n 1 -p "Is \"${artist}\" the correct album artist (y/n)? " iscorrect < /dev/tty && echo
            if [ "${iscorrect}" = 'y' ] || [ "${iscorrect}" = 'Y' ] ; then
                break
            else
                if ${pretagged} ; then
                    read -s -n 1 -p "Do you wish to overwrite the current tag infomration (y/n)? " retagging < /dev/tty && echo
                    if [ "${retagging}" = 'y' ] || [ "${retagging}" = 'Y' ] ; then
                        pretagged=false
                    fi
                fi
                read -p "Enter the album artist: " artist < /dev/tty
            fi
        done
    fi
    if [ ! "${format}" = "Wave" ] && [ ! ${pretagged} ] ; then
        echo "id3 -a \"${artist}\" \"${line}\"" >> "${actsh}"
    fi

    ### Verify Album ###
    if [ -z "${album}" ] ; then
        album="Unknown Album"
        pretagged=false
    else
        pretagged=true
    fi
    if [ ${verifytag} = true ] ; then
        while true ; do
            read -s -n 1 -p "Is \"${album}\" the correct album name (y/n)? " iscorrect < /dev/tty && echo
            if [ "${iscorrect}" = 'y' ] || [ "${iscorrect}" = 'Y' ] ; then
                break
            else
                if ${pretagged} ; then
                    read -s -n 1 -p "Do you wish to overwrite the current tag infomration (y/n)? " retagging < /dev/tty && echo
                    if [ "${retagging}" = 'y' ] || [ "${retagging}" = 'Y' ] ; then
                        pretagged=false
                    fi
                fi
                read -p "Enter the album name: " album < /dev/tty
            fi
        done
    fi
    if [ ! "${format}" = "Wave" ] && [ ! ${pretagged} ] ; then
        echo "id3 -A \"${album}\" \"${line}\"" >> "${actsh}"
    fi

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

    ### Move The File to its Final Destination ###
    if [ ! -e "${destdir}/${filename}" ] ; then
        echo "mv \"${line}\" \"${destdir}/${filename}\"" >> "${actsh}"
    else
        read -s -n 1 -p "Do you wish to overwrite the existing file (y/n)? " replace < /dev/tty && echo
        if [ "${replace}" = 'y' ] || [ "${replace}" = 'Y' ] ; then
            echo "mv \"${line}\" \"${destdir}/${filename}\"" >> "${actsh}"
        fi
    fi

done < ${workdir}/origin.list
