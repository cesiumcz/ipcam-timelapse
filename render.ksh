#!/bin/ksh

. $(dirname "$0")/conf.sh

TMP_UNPROCESSED="${TMPDIR}unprocessed.txt"
TMP_CONCAT="${TMPDIR}concat.txt"
TMP_APPEND="${TMPDIR}append.hevc"
TMP_TIMELAPSE="${TMPDIR}timelapse.hevc"

# Foreach line
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

	TIMELAPSE="${WORKDIR}${wcparam[0]}/timelapse.hevc"
	UNPROCESSED="${WORKDIR}${wcparam[0]}/unprocessed.txt"

	printf "file '$TIMELAPSE'\nfile '$TMP_APPEND'" > "$TMP_CONCAT"

	# Make a copy of unprocessed list and clear it
	cp "$UNPROCESSED" "$TMP_UNPROCESSED"
	> "$UNPROCESSED"

	# Create a video of unprocessed images
	"$FFMPEG" $FFMPEG_COMMON -r $FFMPEG_FPS -f concat -safe 0 -i "$TMP_UNPROCESSED" -c:v libx265 -crf ${wcparam[2]} -preset $FFMPEG_PRESET -x265-params log-level=error -pix_fmt yuv420p "$TMP_APPEND"

	# Append the video at the end of timelapse using concat demuxer
	"$FFMPEG" $FFMPEG_COMMON -f concat -safe 0 -i "$TMP_CONCAT" -c copy "$TMP_TIMELAPSE"

	mv -f "$TMP_TIMELAPSE" "$TIMELAPSE"
	rm -f "$TMP_APPEND" "$TMP_UNPROCESSED"

done < "$CAMERA_LIST"

rm -f "$TMP_CONCAT"

exit 0
