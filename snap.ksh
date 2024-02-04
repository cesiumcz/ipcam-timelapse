#!/bin/ksh

. $(dirname "$0")/conf.sh

# Get current date and time
DATETIME=$(date '+%Y%m%d%H%M')

# Foreach webcam entry
while read line; do
	# Skip empty lines
	if [ -z "$line" ]; then
		continue
	fi

	# Skip commented-out lines
	firstchar=$(printf %.1s "$line")
	if [ "$firstchar" = '#' ]; then
		continue
	fi

	set -A wcparam $line

	# $wcparam[0] = camera name
	# $wcparam[1] = JPEG quality
	# $wcparam[2] = ffmpeg -crf value of the timelapse video
	# $wcparam[3] = RTSP stream URI

	CAMDIR="${WORKDIR}${wcparam[0]}/"
	IMGDIR="${CAMDIR}img/"
	IMG="${IMGDIR}${DATETIME}.jpg"
	mkdir -m 700 -p "$IMGDIR"
	"$FFMPEG" $FFMPEG_COMMON -rtsp_transport tcp -skip_frame nokey -i "${wcparam[3]}" -fps_mode vfr -f image2 -q:v ${wcparam[1]} -frames:v 1 "$IMG" &
	echo "file '$IMG'" >> "${CAMDIR}/unprocessed.txt"
done < "$CAMERA_LIST"

exit 0