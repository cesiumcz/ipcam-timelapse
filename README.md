# cesium RTSP timelapse
Shell script-based routine that takes full-resolution snapshots from IP cam RTSP stream and periodically creates a HEVC timelapse video using FFmpeg.

## Prerequisities
- Shell - `bash` or Korn shell `ksh` (OpenBSD's default shell)
- `ffmpeg` installed from package system or [built with required flags](#compiling-custom-ffmpeg).

## Installation
### System user

	useradd -c "Webcam routine" -b /var/webcam/ -d /var/webcam/ -s /sbin/nologin _webcam
	install -d -m 770 -o root -g _webcam /var/webcam/

### Clone & file copy

	cd /tmp/
	git clone https://github.com/cesiumcz/rtsp-timelapse.git

Determine correct version `bash`/`ksh`:

	mv snap.(bash|ksh) snap.sh
	mv render.(bash|ksh) render.sh

Install the scripts and set correct permissions

	install -d -m 755 -o root -g _webcam /usr/local/webcam/
	install -m 770 -o root -g _webcam conf.sh /usr/local/webcam/
	install -m 754 -o root -g _webcam snap.sh /usr/local/webcam/
	install -m 754 -o root -g _webcam render.sh /usr/local/webcam/
	rm -rf /tmp/rtsp-timelapse/

### Configuration
#### Paths
Set your environment-specific paths and ffmpeg parameters in `conf.sh`

	vim /usr/local/webcam/conf.sh

#### Camera list

	vim /usr/local/webcam/cameras.txt

For each webcam, insert a line according to the following syntax:

	cam_name jpg_quality ffmpeg_crf rtsp_uri

- *cam_name* = unique string camera name. Use short and simple names.
- *jpg_quality* = JPEG snapshot quality. The normal range for JPEG is 2-31 with 31 being the worst quality. Can be used to optimize storage footprint.  
  **Once a snapshot is taken, its quality cannot be increased.**
- *ffmpeg_crf* = Use Constant Rate Factor (CRF) to control the quality of the timelapse video. The default is 28. See [H.265 documentation](https://trac.ffmpeg.org/wiki/Encode/H.265).
- *rtsp_uri* = RTSP stream URI

A line starting with `#` is ignored.

Example contents of `cameras.txt`

	entrance 20 28 rtsp://192.168.1.100/user=monitor_password=pdTzQLK6Iq_channel=1_stream=0.sdp
	backyard 25 40 rtsp://192.168.1.101/user=monitor_password=6oLA64UG_channel=1_stream=0.sdp

Set proper permissions (`cameras.txt` is likely to contain credentials)

	chown -R root:_webcam /usr/local/webcam/
	chmod 660 /usr/local/webcam/cameras.txt

### Cron
Grab a snapshot every hour, and render video once a day. In this manner, one day equals 1 second in the final 24 FPS timelapse video.  
**NOTICE: Prevent render to execute at the same time as snap and set sufficient delay as follows.**

	crontab -e -u _webcam
	0 * * * * /usr/local/webcam/snap.sh
	5 3 * * * /usr/local/webcam/render.sh

## Changing timelapse video parameters
Since `render.sh` appends a new video segment at the end of the timelapse without reencoding it completely, any change of output timelapse video parameters (FPS, CRF, Preset) must be followed by a complete reencode.  
**WARNING: This operation may be very source consumptive and can take a long time.**  
Users are discouraged to execute a such operation on a production machine. Use a dedicated machine instead.

	tar -czf /tmp/webc_backup.tar.gz /var/webcam/cam1/img/

Transfer the archive to dedicated machine and reencode the video

	ffmpeg -pattern_type glob -i "cam1/img/*.jpg" -r <FFMPEG_FPS> -c:v libx265 -crf <CRF> -preset <PRESET> -pix_fmt yuv420p cam1/timelapse.hevc

...and place the video back on the server

## Testing

	su -l _webcam /usr/local/webcam/snap.sh
	su -l _webcam /usr/local/webcam/render.sh

[Alternatively] using `doas` command:

	doas -u _webcam /usr/local/webcam/snap.sh

## Modus operandi
**`snap.sh`** does the following sequentially for each webcam:
- takes a JPEG snapshot of specified quality,
- saves the output image in webcam specific directory with a filename containing the date and time of the snapshot,
- appends the filename to the list of unprocessed files `unprocessed.txt`

**`render.sh`** does the following sequentially for each webcam:
- creates a temporary copy of `unprocessed.txt` list of images that are to be encoded and clears the original list,
- renders a short video to the temporary directory from images in `unprocessed.txt` list,
- appends the short video at the end of the existing timelapse without reencoding the whole video using ffmpeg's demuxer

*A temporary video is necessary because ffmpeg cannot append images directly to the existing video, it supports video concatenation instead.*

### Directory structure
	/var/webcam/
	|-- cam1
	|   |-- img
	|   |   |-- 202402041000.jpg
	|   |   `-- 202402041100.jpg
	|   |-- timelapse.hevc
	|   `-- unprocessed.txt
	`-- cam2
	    |-- img
	    |   |-- 202402041000.jpg
	    |   `-- 202402041100.jpg
	    |-- timelapse.hevc
	    `-- unprocessed.txt

## Compiling custom `ffmpeg`
Below is the very minimal build configuration needed to run `rtsp-timelapse` with H.264 and H.265 cameras. It produces ~4.8 MiB executable for amd64 with `gcc`. This may be useful for resource-limited or security-oriented scenarios.  

### Prerequisities
- [`libx264`](https://trac.ffmpeg.org/wiki/CompilationGuide/Ubuntu#libx264)
- [`libx265`](https://trac.ffmpeg.org/wiki/CompilationGuide/Ubuntu#libx265)

In case you do not need timelapse video generation, you can omit `--enable-encoder=libx265`, `--enable-demuxer=concat`, `--enable-decoder=mjpeg`, `--enable-muxer=hevc`.  
Furthermore, you can choose `libx264/h264` / `libx265/h265` according to your IP camera capabilities.
```
cd /tmp
git clone https://github.com/FFmpeg/FFmpeg.git
cd FFmpeg

./configure \
  --enable-gpl --enable-version3 \
  --enable-libopenjpeg --enable-libx264 --enable-libx265 \
  --disable-ffplay --disable-ffprobe --disable-doc \
  --disable-logging --disable-debug \
  --disable-iconv --disable-lzma --disable-zlib \
  --disable-swresample --disable-postproc --disable-pixelutils \
  --disable-everything \
  --enable-encoder=mjpeg --enable-encoder=libx265 \
  --enable-decoder=h264 --enable-decoder=hevc --enable-decoder=mjpeg \
  --enable-protocol=concat --enable-protocol=file --enable-protocol=tcp --enable-protocol=udp \
  --enable-muxer=rtsp --enable-muxer=image2 --enable-muxer=hevc \
  --enable-demuxer=rtsp --enable-demuxer=concat --enable-demuxer=image2 \
  --enable-filter=scale \
  --enable-parser=h264 --enable-parser=hevc

make -j4
make install
```

## Author
[Matyáš Vohralík](https://mv.cesium.cz), 2024

## License
[BSD 3-Clause](LICENSE)
