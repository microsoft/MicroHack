#!/bin/bash

# https://github.com/jclem/gifify
# Bash script which does make use of ffmpeg and imagemagick to create an animated gif from a mpf4 video file.
# Usage: ./mp4togif.sh <input file> <output file>
# Example: ./mp4togif.sh input.mp4 output.gif

# Check if the number of arguments is correct.
if [ $# -ne 2 ]; then
    echo "Usage: $0 <input file> <output file>"
    exit 1
fi

inputFileName=$1
echo $inputFileName
outputFileName=$2
echo $outputFileName

# Check if the input file exists.
if [ ! -f "$inputFileName" ]; then
    echo "Input file $inputFileName does not exist."
    exit 1
fi

# Check if the output file has the correct extension.
if [ "${outputFileName##*.}" != "gif" ]; then
    echo "Output file $outputFileName should have the extension .gif."
    exit 1
fi

# Check if ffmpeg is installed.
if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "ffmpeg is not installed."
    exit 1
fi

# Check if imagemagick is installed.
if ! command -v convert >/dev/null 2>&1; then
    echo "imagemagick is not installed."
    exit 1
fi

width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=s=x:p=0 $inputFileName)
fps=10
speed=1
delay=$(bc -l <<< "100/$fps/$speed")

ffmpeg -i $inputFileName -vf scale=$width:-1:flags=lanczos -r $fps  -f image2pipe -vcodec ppm - > ./media/mp4tgif.ppm
cat ./media/mp4tgif.ppm | convert +dither -delay $delay -loop 0 - ./media/mp4tgif.large.gif
gifsicle --optimize=3 --use-colormap web ./media/mp4tgif.large.gif > $outputFileName


# Convert the video to frames
# ffmpeg -i $inputFileName -vf "fps=$fps,scale=$width:-1:flags=lanczos" -c:v pam -f image2 ./media/output/frame%03d.pam
# convert -layers Optimize -delay 10 -loop 0 ./media/output/frame*.pam ./media/mp4tgif.large.gif
# gifsicle --optimize=3 --use-colormap web ./media/mp4tgif.large.gif > $outputFileName

######
# First pass: generate palette
# ffmpeg -y -i $inputFileName -vf "fps=10,scale=$width:-1:flags=lanczos,palettegen" ./media/palette.png
# # Second pass: use palette to create GIF
# ffmpeg -i $inputFileName -i ./media/palette.png -filter_complex "fps=10,scale=$width:-1:flags=lanczos[x];[x][1:v]paletteuse" ./media/output.large.gif
# # Optimize GIF
# gifsicle --optimize=3 --colors 512 ./media/output.large.gif > ./media/output.small.gif 
######
# rm ./media/mp4tgif.ppm
# rm ./media/mp4tgif.large.gif

