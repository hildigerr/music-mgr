#!/bin/bash


### Exit Status Table ###
# 0 == Success
# 1 == Invalid Parameter Flag


askyn() { read -s -n 1 -p "$1 (y/n)? " $2 </dev/tty && echo; }
usage() { echo "Usage: $0 [-vpgcxy] [-t <target directory>] [-m genre map file] FILE..." 1>&2; exit 1; }

### Variables ###
while getopts ":Y:G:A:R:t:m:vpgcxy" o; do
    case "${o}" in
        Y) default_year=${OPTARG} ;;
        G) default_genre=${OPTARG} ;;
        A) default_artist=${OPTARG} ;;
        R) default_album=${OPTARG} ;;
        t) dest=${OPTARG} ;;
        m) map_genres=${OPTARG} ;;
        v) verbose=true ;;
        p) playbg=true ;;
        c) put=cp ;;
        g) guess=true ;;
        x) autox=true ;;
        y) autoy=true ;;
        *) usage ;;
    esac
done
recursive_options=("${@:1:$((OPTIND-1))}")
shift $((OPTIND-1))

### Default Values ###
if [ -z "${verbose}" ] ; then verbose=false ; fi
if [ -z "${playbg}" ] ; then playbg=false ; fi
if [ -z "${put}" ] ; then put=mv ; fi
if [ -z "${guess}" ] ; then guess=false ; fi
if [ -z "${autox}" ] ; then autox=false ; fi
if [ -z "${autoy}" ] ; then autoy=false ; fi
if [ -z "${dest}" ] ; then dest="${HOME}/Music" ; fi
if [ -z "${map_genres}" ] ; then map_genres="${HOME}/.config/map_genres.sh" ; fi
if [ -z "${default_artist}" ] ; then default_artist="Various Artists" ; fi
if [ -z "${default_album}" ] ; then default_album="Unknown Album" ; fi
if [ -z "${default_genre}" ] ; then default_genre="Other" ; fi
if [ -z "${default_year}" ] ; then default_year=`date  +%Y` ; fi

if [ ! -e "${map_genres}" ] ; then
    if ${verbose} ; then echo "Generating genre map: \"${map_genres}\"" ; fi
    echo "declare -A GENRE_DIRMAP" > "${map_genres}"
    mtag -L | awk '{printf "GENRE_DIRMAP[%s]=\"%s\"\n", $0, $0}' >> "${map_genres}"
    # Append Missing Genres
    echo "GENRE_DIRMAP[Children\\'s]=\"Children's\"" >> "${map_genres}"
    echo "GENRE_DIRMAP[Power Metal]=\"Power Metal\"" >> "${map_genres}"
    echo "GENRE_DIRMAP[Trap]=\"Trap\"" >> "${map_genres}"
fi
source "${map_genres}"

if ${verbose} ; then
    echo "dest = ${dest}"
fi

for line in "$@"; do
    echo -e "\nFile: ${line}"

    ### Process Playlists ###
    ythash=${line/https:\/\/www.youtube.com\/playlist?list=}
    if [ "${ythash}" != "${line}" ] ; then
        for each in `curl "${line}" | grep -o "watch?v=..........."`; do
            collect_music "${recursive_options[@]}" "https://www.youtube.com/$each"
        done
        continue
    fi

    ### Get Placeholder Song ###
    ythash=${line/https:\/\/www.youtube.com\/watch?v=}
    if [ "${ythash}" != "${line}" ] ; then
        num=`youtube-dl -F "${line}" | grep audio | tail -n 1 | awk '{print $1}'`
        youtube-dl --extract-audio --output "/tmp/%(title)s-%(id)s.%(ext)s" -f "${num}" "${line}"
        line=`ls /tmp/*"${ythash}"* | tail -n1`
    else
        ythash=''
    fi

    ### Get Basic File Data ###
    filename=`basename "${line}"`

    ### Retrieve Media Tag Data ###
    data=`mtag -l= "${line}"`
    case $? in
        0)
            untagged=false
            track=`grep -i -m 1 "^TRACKNUMBER" <<<"${data}" | cut -d= -f 2`
            title=`grep -i -m 1 "^TITLE" <<<"${data}" | cut -d= -f 2`
            artist=`grep -i -m 1 "^ARTIST" <<<"${data}" | cut -d= -f 2`
            album=`grep -i -m 1 "^ALBUM" <<<"${data}" | cut -d= -f 2`
            year=`grep -i -m 1 "^DATE" <<<"${data}" | cut -d= -f 2`
            genre=`grep -i -m 1 "^GENRE" <<<"${data}" | cut -d= -f 2`
            comment=`grep -i -m 1 "^COMMENT" <<<"${data}" | cut -d= -f 2`
            ;;
        1|5) echo "ERROR: $0 corrupted!" &  exit 1 ;;
        2|3) if ${verbose} ; then echo "[Unsupported file type, skipping...]" ; fi && continue ;;
        4) # Untagged
            untagged=true
            track=''
            title=''
            artist=''
            album=''
            year=''
            genre=''
            comment=''
            ;;
    esac

    ### Default Tag Values ###
    if  [ -z "${title}" ] ; then
        title="${filename%.*}"
        if [ ! -z "${ythash}" ] ; then
            title=`echo "${title}" | sed -e "s/.${ythash}//"`
        fi
    fi
    if [ -z "${artist}" ] || [ "${artist}" = "Various" ] ; then
        artist="${default_artist}"
    fi
    if [ -z "${album}" ] ; then
        album="${default_album}"
    fi
    if [ -z "${year}" ] ; then
        year="${default_year}"
    fi
    if [ -z "${track}" ] ; then
        track="01"
    fi
    if [ -z "${genre}" ] ; then
        genre="${default_genre}"
    fi
    if [ -z "${comment}" ] ; then
        comment="${ythash}"
    fi

    ### Make Guesses ###
    if ${guess} ; then
        artist_guess=`echo ${line} | rev | cut -d/ -f 3 | rev | sed s/^\.$//`
        album_guess=`echo ${line} | rev | cut -d/ -f 2 | rev | sed s/^\.$//`
        genre_guess=`echo ${line} | rev | cut -d/ -f 4 | rev | sed s/^\.$//`
    fi

    ### Prepare to Update Tags ###
    params=()
    if $playbg ; then
        killall play 2>/dev/null
        play -q "${line}" &
    fi
    echo "track = ${track}"
    echo "title = ${title}"
    echo "artist = ${artist}"
    echo "album = ${album}"
    echo "year = ${year}"
    echo "genre = ${genre}"
    echo "comment = ${comment}"

    if [ ! -z ${ythash} ] || $untagged; then
        tagok='N'
    elif ${autoy} ; then
        tagok='Y'
    else
        askyn "Do you trust this file to be tagged correctly" tagok
    fi
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
        askyn "Is \"${artist}\" the correct artist" iscorrect
        if [ "${iscorrect}" = 'n' ] || [ "${iscorrect}" = 'N' ] ; then
            if [ -n "${artist_guess}" ] && [ "${artist_guess}" != "${artist}" ]; then
                if ${verbose} ; then
                    echo "Guessing artist based on path..."
                fi
                artist=${artist_guess}
            else
                read -p "Enter the artist: " artist < /dev/tty
            fi

            while true ; do
                askyn "Is \"${artist}\" the correct artist" iscorrect
                if [ "${iscorrect}" = 'y' ] || [ "${iscorrect}" = 'Y' ] ; then
                    break
                else
                    read -p "Enter the artist(s): " artist < /dev/tty
                fi
            done
        fi
        if [ -n "${artist}" ] ; then params+=(-a "${artist}") ; fi

    ### Verify Album ###
        askyn "Is \"${album}\" the correct album name" iscorrect
        if [ "${iscorrect}" = 'n' ] || [ "${iscorrect}" = 'N' ] ; then
            if [ -n "${album_guess}" ] && [ "${album_guess}" != "${album}" ] ; then
                if ${verbose} ; then
                    echo "Guessing album based on path..."
                fi
                album=${album_guess}
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
        if [ -n "${album}" ] && [ "${album}" != "Unknown Album" ] ; then params+=(-A "${album}") ; fi

    ### Verify Year ###
        while true ; do
            askyn "Is \"${year}\" the correct album year" iscorrect
            if [ "${iscorrect}" = 'y' ] || [ "${iscorrect}" = 'Y' ] ; then
                break
            else
                read -p "Enter the album year: " year < /dev/tty
            fi
        done
        if [ -n "${year}" ] ; then params+=(-y "${year}") ; fi

    ### Verify Track Number ###
        while true ; do
            askyn "Is \"${track}\" the correct track number" iscorrect
            if [ "${iscorrect}" = 'y' ] || [ "${iscorrect}" = 'Y' ] ; then
                break
            else
                read -p "Enter the track number: " track < /dev/tty
            fi
        done
        if [ -n "${track}" ] ; then params+=(-n "${track}") ; fi

    ### Verify Genre ###
        askyn "Is \"${genre}\" the correct artist genre" iscorrect
        if [ "${iscorrect}" = 'n' ] || [ "${iscorrect}" = 'N' ] ; then
            if [ -n "${genre_guess}" ] && [ "${genre_guess}" != "${genre}" ] ; then
                if ${verbose} ; then
                    echo "Guessing genre based on path..."
                fi
                genre=${genre_guess}
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

    ### Verify Comment ###
        while true ; do
            askyn "Tag with comment \"${comment}\"" iscorrect
            if [ "${iscorrect}" = 'y' ] || [ "${iscorrect}" = 'Y' ] ; then
                break
            else
                read -p "Enter the comment: " comment < /dev/tty
            fi
        done
        if [ -n "${comment}" ] ; then params+=(-c "${comment}") ; fi

    fi

    ### Update Tags ###
    if ! ${autoy} && [ ${#params[@]} -gt 0 ] ; then
        if ${verbose} ; then
            echo
            echo "title = ${title}"
            echo "artist = ${artist}"
            echo "album = ${album/Unknown Album/}"
            echo "year = ${year}"
            echo "track = ${track}"
            echo "genre = ${genre}"
            echo "comment = ${comment}"
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


    ### Setup Destination Directory Structure ###
    destdir="${dest}/${GENRE_DIRMAP[${genre}]:-Other}/${artist:-Unknown Artist}/${album:-Singles}"
    echo "destination = \"${destdir}\""
    if ${autoy} ; then
        confirm='Y'
    else
        askyn "Is this the desired destination" confirm
    fi
    if [ "${confirm}" = 'n' ] || [ "${confirm}" = 'N' ] ; then
        destdir="${dest}/${GENRE_DIRMAP[${genre}]:-Other}/Various Artists/${album:-Singles}"
        while true ; do
            echo "destination = \"${destdir}\""
            askyn "Is this the desired destination" confirm
            if [ "${confirm}" = 'y' ] || [ "${confirm}" = 'Y' ] ; then
                break
            else
                read -p "Enter the desired destination: " destdir < /dev/tty
            fi
        done
    fi
    if [ ! -d "${destdir}" ] ; then
        mkdir -vp "${destdir}"
    fi

    ### Verify Filename ###
    if ! ${autoy} ; then
        echo "filename = \"${filename}\""
        askyn "Is this the desired filename" confirm
        if [ "${confirm}" = 'n' ] || [ "${confirm}" = 'N' ] ; then
            filename="${track:-${artist}} - ${title}.${filename##*.}"
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
        ${put} "${line}" "${destdir}/${filename}"
    elif [ "${line}" != "${destdir}/${filename}" ] ; then
        fisz=`du -h "${line}" | cut -f 1`
        fimd=`md5sum "${line}"`
        ffsz=`du -h "${destdir}/${filename}" | cut -f 1`
        ffmd=`md5sum "${destdir}/${filename}"`
        echo -e "Size MD5Sum                           Filename"
        echo -e "${fisz} ${fimd}\n${ffsz} ${ffmd}"
        if ${autox} ; then
            replace='N'
        else
            askyn "Do you wish to overwrite the existing file" replace
        fi
        if [ "${replace}" = 'y' ] || [ "${replace}" = 'Y' ] ; then
            ${put} "${line}" "${destdir}/${filename}"
        else
            if ${autox} ; then
                remove='N'
            else
                askyn "Do you wish to keep both files" remove
            fi
            if [ "${remove}" = 'n' ] || [ "${remove}" = 'N' ] ; then
                rm "${line}"
            fi
        fi
    fi

done

