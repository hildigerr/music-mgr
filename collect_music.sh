#!/bin/bash

source map_genres.sh

### Exit Status Table ###
# 0 == Success
# 1 == Invalid Parameter Flag

### TODO:
# Edit arbitrary tag fields.
# Remove/update deprecated tag fields. https://id3.org/id3v2.4.0-changes
# Add auto yes iscorrect option.

askyn() { read -s -n 1 -p "$1 (y/n)? " $2 </dev/tty && echo; }
usage() { echo "Usage: $0 [-vrpg] [-t <target directory>] FILE..." 1>&2; exit 1; }

### Variables ###
while getopts ":t:vrpg" o; do
    case "${o}" in
        t) dest=${OPTARG} ;;
        v) verbose=true ;;
        r) renameq=true ;;
        p) playbg=true ;;
        g) guess=true ;;
        *) usage ;;
    esac
done
shift $((OPTIND-1))

### Default Values ###
if [ -z "${verbose}" ] ; then verbose=false ; fi
if [ -z "${renameq}" ] ; then renameq=false ; fi
if [ -z "${playbg}" ] ; then playbg=false ; fi
if [ -z "${guess}" ] ; then guess=false ; fi
if [ -z "${dest}" ] ; then dest="${HOME}/Music" ; fi

if ${verbose} ; then
    echo "dest = ${dest}"
fi

for line in "$@"; do
    echo -e "\nFile: ${line}"

    ### Get Placeholder Song ###
    ythash=${line/https:\/\/www.youtube.com\/watch?v=}
    if [ "${ythash}" != "${line}" ] ; then
        youtube-dl -F "${line}"
        read -p "Select format code: " num </dev/tty && echo
        youtube-dl --extract-audio --output "/tmp/%(title)s-%(id)s.%(ext)s" -f "${num}" "${line}"
        line=`ls /tmp/*"${ythash}"* | tail -n1`
    fi

    ### Get Basic File Data ###
    filename=`basename "${line}"`

    ### Retrieve Media Tag Data ###
    data=`mtag -l= "${line}"`
    case $? in
        0)
            title=`grep -i -m 1 "^TITLE" <<<"${data}" | cut -d= -f 2`
            artist=`grep -i -m 1 "^ARTIST" <<<"${data}" | cut -d= -f 2`
            album=`grep -i -m 1 "^ALBUM" <<<"${data}" | cut -d= -f 2`
            year=`grep -i -m 1 "^DATE" <<<"${data}" | cut -d= -f 2`
            genre=`grep -i -m 1 "^GENRE" <<<"${data}" | cut -d= -f 2`
            ;;
        1|5) echo "ERROR: $0 corrupted!" &  exit 1 ;;
        2|3) if ${verbose} ; then echo "[Unsupported file type, skipping...]" ; fi && continue ;;
        4) # Untagged
            title=''
            artist=''
            album=''
            year=''
            genre=''
            ;;
    esac

    if  [ -z "${title}" ] ; then
        title=${filename}
    fi
    if [ -z "${artist}" ] || [ "${artist}" = "Various" ] ; then
        artist="Various Artists"
    fi
    if [ -z "${album}" ] ; then
        album="Unknown Album"
    fi
    if [ -z "${genre}" ] ; then
        genre="Other"
    fi

    ### Prepare to Update Tags ###
    params=()
    if $playbg ; then
        killall play 2>/dev/null
        play -q "${line}" &
    fi
    echo "title = ${title}"
    echo "artist = ${artist}"
    echo "album = ${album}"
    echo "year = ${year}"
    echo "genre = ${genre}"
    askyn "Do you trust this file to be tagged correctly" tagok
    if [ "${tagok}" = 'n' ] || [ "${tagok}" = 'N' ] ; then

    ### Verify Title ###
        while true ; do
            askyn "Is \"${title}\" the correct song title" iscorrect
            if [ "${iscorrect}" = 'y' ] || [ "${iscorrect}" = 'Y' ] ; then
                break
            else
                read -p "Enter the song title: " title < /dev/tty
            fi
        done
        if [ -n "${title}" ] ; then params+=(-t "${title}") ; fi

    ### Verify Artist ###
        askyn "Is \"${artist}\" the correct album artist" iscorrect
        if [ "${iscorrect}" = 'n' ] || [ "${iscorrect}" = 'N' ] ; then
            if ${guess} ; then
                if ${verbose} ; then
                    echo "Guessing artist based on path..."
                fi
                artist=`echo ${line} | rev | cut -d/ -f 3 | rev`
            else
                read -p "Enter the album artist: " artist < /dev/tty
            fi

            while true ; do
                askyn "Is \"${artist}\" the correct album artist" iscorrect
                if [ "${iscorrect}" = 'y' ] || [ "${iscorrect}" = 'Y' ] ; then
                    break
                else
                    read -p "Enter the album artist: " artist < /dev/tty
                fi
            done
        fi
        if [ -n "${artist}" ] ; then params+=(-a "${artist}") ; fi

    ### Verify Album ###
        askyn "Is \"${album}\" the correct album name" iscorrect
        if [ "${iscorrect}" = 'n' ] || [ "${iscorrect}" = 'N' ] ; then
            if ${guess} ; then
                if ${verbose} ; then
                    echo "Guessing album based on path..."
                fi
                album=`echo ${line} | rev | cut -d/ -f 2 | rev`
            else
                read -p "Enter the album name: " album < /dev/tty
            fi

            while true ; do
                askyn "Is \"${album}\" the correct album name" iscorrect
                if [ "${iscorrect}" = 'y' ] || [ "${iscorrect}" = 'Y' ] ; then
                    break
                else
                    read -p "Enter the album name: " album < /dev/tty
                fi
            done
        fi
        if [ -n "${album}" ] ; then params+=(-A "${album}") ; fi

    ### Verify Year ###
        if [ -z "${year}" ] ; then
            askyn "Do you want to add the album year tag" confirm
            if [ "${confirm}" = 'y' ] || [ "${confirm}" = 'Y' ] ; then
                year=`date  +%Y`
            fi
        fi
        if [ -n "${year}" ] ; then
            while true ; do
                askyn "Is \"${year}\" the correct album year" iscorrect
                if [ "${iscorrect}" = 'y' ] || [ "${iscorrect}" = 'Y' ] ; then
                    break
                else
                    read -p "Enter the album year: " year < /dev/tty
                fi
            done
        fi
        if [ -n "${year}" ] ; then params+=(-y "${year}") ; fi

    ### Verify Genre ###
        askyn "Is \"${genre}\" the correct artist genre" iscorrect
        if [ "${iscorrect}" = 'n' ] || [ "${iscorrect}" = 'N' ] ; then
            if ${guess} ; then
                if ${verbose} ; then
                    echo "Guessing genre based on path..."
                fi
                genre=`echo ${line} | rev | cut -d/ -f 4 | rev`
            else
                read -p "Enter the artist genre: " genre < /dev/tty
            fi

            while true ; do
                askyn "Is \"${genre}\" the correct artist genre" iscorrect
                if [ "${iscorrect}" = 'y' ] || [ "${iscorrect}" = 'Y' ] ; then
                    break
                else
                    read -p "Enter the artist genre: " genre < /dev/tty
                fi
            done
        fi
        if [ -n "${genre}" ] ; then params+=(-g "${genre}") ; fi

    fi

    ### Update Tags ###
    if [ ${#params[@]} -gt 0 ] ; then
        if ${verbose} ; then
            echo
            echo "title = ${title}"
            echo "artist = ${artist}"
            echo "album = ${album}"
            echo "year = ${year}"
            echo "genre = ${genre}"
        fi
        askyn "Ok to write the tags" confirm
        if [ "${confirm}" = 'y' ] || [ "${confirm}" = 'Y' ] ; then
            echo "Writing the tags..."
            mtag "${params[@]}" "${line}"
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

    askyn "Is the file already in the desired location" confirm
    if [ "${confirm}" = 'y' ] || [ "${confirm}" = 'Y' ] ; then
        continue
    fi

    ### Setup Destination Directory Structure ###
    destdir="${dest}/${GENRE_DIRMAP[${genre}]}/${artist}/${album}"
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

    ### Verify Filename ###
    if $renameq ; then
        echo "filename = \"${filename}\""
        askyn "Is this the desired filename" confirm
        if [ "${confirm}" = 'n' ] || [ "${confirm}" = 'N' ] ; then
            filename="${title}.${filename##*.}"
            while true ; do
                echo "filename = \"${filename}\""
                askyn "Is this the desired filename" confirm
                if [ "${confirm}" = 'y' ] || [ "${confirm}" = 'Y' ] ; then
                    break
                else
                    read -p "Enter the desired filename: " filename < /dev/tty
                fi
            done
        fi
    fi

    ### Move The File to its Final Destination ###
    if [ ! -e "${destdir}/${filename}" ] ; then
        mv "${line}" "${destdir}/${filename}"
    elif [ "${line}" != "${destdir}/${filename}" ] ; then
        fisz=`du -h "${line}" | cut -f 1`
        fimd=`md5sum "${line}"`
        ffsz=`du -h "${destdir}/${filename}" | cut -f 1`
        ffmd=`md5sum "${destdir}/${filename}"`
        echo -e "Size MD5Sum                           Filename"
        echo -e "${fisz} ${fimd}\n${ffsz} ${ffmd}"
        askyn "Do you wish to overwrite the existing file" replace
        if [ "${replace}" = 'y' ] || [ "${replace}" = 'Y' ] ; then
            mv "${line}" "${destdir}/${filename}"
        fi
    fi

done

