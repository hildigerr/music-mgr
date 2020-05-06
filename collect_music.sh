#!/bin/bash

### Dependencies: mediainfo, id3 or id3tool, [vorbis-tools (ogginfo,vorbiscomment)]?

### Exit Status Table ###
#-1 == Clean Up Action Interrupted
# 0 == Success
# 1 == Invalid Parameter Flag
# 2 == Missing Directory

### TODO:
# Write/update ogg tags.
# Edit arbitrary tag fields.
# Add auto yes iscorrect option.

askyn() { read -s -n 1 -p "$1 (y/n)? " $2 </dev/tty && echo; }
usage() { echo "Usage: $0 [-vc] [-s <source directory>] [-t <target directory>]" 1>&2; exit 1; }
nodir() { echo "ERROR: $1 does not exist or is not a directory." 1>&2; exit 2; }

### Variables ###
while getopts ":s:t:vc" o; do
    case "${o}" in
        s) srcdir=${OPTARG} ;;
        t) dest=${OPTARG} ;;
        v) verbose=true ;;
        c) cleanup=true ;;
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

### Clean Up Action ###
# Stop and Resume at any moment. When ready to finalize,
# run with cleanup option [-c] to execute queued actions.
# If a mistake is made stop immedietly and remove the
# corrosponding lines from actions.sh
if [ ! -z $cleanup ] ; then
    if ${verbose} ; then
        echo "[CLEAN] Running \"${actsh}\" ..."
    fi
    bash "${actsh}"
    status=$?
    if [ $status -eq -1 ] ; then
        #TODO: Echo explanation or instructions.
        exit -1
    else
        mv "${actsh}" "${actsh}-`date +%Y%m%d`"
        exit 0
    fi
fi

if ${verbose} ; then
    echo "srcdir = ${srcdir}"
    echo "dest = ${dest}"
    echo "workdir = ${workdir}"
fi

if [ ! -d "${workdir}" ] ; then
    mkdir -vp "${workdir}"
fi
if [ ! -e "${actsh}" ] ; then
    echo "#!/bin/bash" > "${actsh}"
else
    echo >> "${actsh}"
    echo "### Remove duplicate or invalid actions. And then ..." >> "${actsh}"
    echo "echo \"[WARNING] Edit actions file then continue.\"" >> "${actsh}"
    echo "echo \"Actions File: $actsh\"" >> "${actsh}"
    echo "exit -1" >> "${actsh}"
    echo "### Resume from here:" >> "${actsh}"
fi

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
        id3 -l "${line}" #XXX mediainfo doesn't show id3's tag changes XXX
        title=`grep -m 1 "^Track name " <<<"${data}" | cut -d: -f 2- | sed 's/^ *//g'`
        artist=`grep -m 1 "^Album/Performer" <<<"${data}" | cut -d: -f 2- | sed 's/^ *//g'`
        album=`grep -m 1 "^Album" <<<"${data}" | cut -d: -f 2- | sed 's/^ *//g'`
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
    askyn "Do you trust this file to be tagged correctly" tagok
    if [ "${tagok}" = 'y' ] || [ "${tagok}" = 'Y' ] ; then
        verifytag=false
    else
        askyn "Is the problem that the album artist should be \"Various Artists\"" quickfix
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
            askyn "Is \"${title}\" the correct song title" iscorrect
            if [ "${iscorrect}" = 'y' ] || [ "${iscorrect}" = 'Y' ] ; then
                break
            else
                if ${pretagged} ; then
                    askyn "Do you wish to overwrite the current tag infomration" retagging
                    if [ "${retagging}" = 'y' ] || [ "${retagging}" = 'Y' ] ; then
                        pretagged=false
                    fi
                fi
                read -p "Enter the song title: " title < /dev/tty
            fi
        done
    fi
    if [ "${format}" = "MPEG Audio" ] && [ ! ${pretagged} ] ; then
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
            askyn "Is \"${artist}\" the correct album artist" iscorrect
            if [ "${iscorrect}" = 'y' ] || [ "${iscorrect}" = 'Y' ] ; then
                break
            else
                if ${pretagged} ; then
                    askyn "Do you wish to overwrite the current tag infomration" retagging
                    if [ "${retagging}" = 'y' ] || [ "${retagging}" = 'Y' ] ; then
                        pretagged=false
                    fi
                fi
                read -p "Enter the album artist: " artist < /dev/tty
            fi
        done
    fi
    if [ "${format}" = "MPEG Audio" ] && [ ! ${pretagged} ] ; then
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
            askyn "Is \"${album}\" the correct album name" iscorrect
            if [ "${iscorrect}" = 'y' ] || [ "${iscorrect}" = 'Y' ] ; then
                break
            else
                if ${pretagged} ; then
                    askyn "Do you wish to overwrite the current tag infomration" retagging
                    if [ "${retagging}" = 'y' ] || [ "${retagging}" = 'Y' ] ; then
                        pretagged=false
                    fi
                fi
                read -p "Enter the album name: " album < /dev/tty
            fi
        done
    fi
    if [ "${format}" = "MPEG Audio" ] && [ ! ${pretagged} ] ; then
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
        askyn "Do you wish to overwrite the existing file" replace
        if [ "${replace}" = 'y' ] || [ "${replace}" = 'Y' ] ; then
            echo "mv \"${line}\" \"${destdir}/${filename}\"" >> "${actsh}"
        fi
    fi

done < ${workdir}/origin.list

echo "find \"${srcdir}\" -depth -type d -empty -exec rmdir {} \;" >> "${actsh}"
