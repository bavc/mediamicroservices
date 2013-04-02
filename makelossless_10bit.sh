#!/bin/sh
file="$1"
filename=`basename "$file"`
dirname=`dirname "$file"`

isv210=`ffprobe 2>/dev/null -i "$file" -show_streams | grep v210 | wc -l | sed 's/ //g'`
echo "$file is $isv210"
if [[ "$isv210" -eq 0 ]] ; then
    echo "$filename is not v210, quitting"
    exit 1
else
    echo "$filename is v210, starting encode"
    export FFREPORT="file=${dirname}/%p_%t_convert-to-ffv1.log"
    ffmpeg -report -vsync 0 -i "$file" -map 0:v -map 0:a -c:v ffv1 -g 1 -c:a copy "${file%.*}_ffv1.mov" -f framemd5 -an "${file%.*}.framemd5"
    ffmpeg_ffv1_err="$?"
    [ "$ffmpeg_ffv1_err" -gt 0 ] && echo ffmpeg ended with error && exit 1
    ffmpeg -i "${file%.*}_ffv1.mov"  -f framemd5 -an "${file%.*}_ffv1.framemd5"
    ffmpeg_md5_err="$?"
    [ "$ffmpeg_md5_err" -gt 0 ] && echo ffmpeg md5 ended with error && exit 1
    muxmovie "$file" -track "Timecode Track" -track "Closed Caption Track" -self-contained -o "${file%.*}_tc_e608.mov"
    muxmovie_err="$?"
    [ "$muxmovie_err" -gt 0 ] && echo muxmovie ended with error && exit 1
    if [ `md5 -q "${file%.*}.framemd5"` = `md5 -q "${file%.*}_ffv1.framemd5"` ] ; then
        echo Everything looks safe. Going to delete the original.
        mediainfo -f --language=raw --output=XML "$file" > "${file%.*}_mediainfo.xml"
        rm -f -v "$file"
    else
        echo Not looking safe. Going to keep the original.
    fi
    echo done with "$file"
fi