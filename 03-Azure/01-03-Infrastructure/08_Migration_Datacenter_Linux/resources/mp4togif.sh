#!/bin/bash

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

ffmpeg -i $inputFileName -vf scale=320:-1 -r 10 -f image2pipe -vcodec ppm - >> ./mp4tgif.tmp
cat ./mp4tgif.tmp | convert +dither -delay 5 -loop 0 - $outputFileName
rm ./mp4tgif.tmp

