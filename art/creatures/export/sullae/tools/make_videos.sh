#!/bin/sh
# render_clips.py 가 찍은 프레임 폴더(<Clip>_<mode>/f####.png) → mp4(소리 없음) + gif
#   sh make_videos.sh <frames_dir> <videos_dir>
FR="$1"; VD="$2"; mkdir -p "$VD"
for d in "$FR"/*/; do
  n=$(basename "$d")
  ffmpeg -loglevel error -y -framerate 30 -i "$d/f%04d.png" -an -c:v libx264 -pix_fmt yuv420p -crf 22 -movflags +faststart "$VD/$n.mp4" || \
  ffmpeg -loglevel error -y -framerate 30 -start_number 0 -i "$d/f%04d.png" -an -c:v libx264 -pix_fmt yuv420p -crf 22 "$VD/$n.mp4"
  ffmpeg -loglevel error -y -framerate 30 -i "$d/f%04d.png" -vf "fps=15,scale=300:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=96[p];[b][p]paletteuse=dither=bayer:bayer_scale=4" -loop 0 "$VD/$n.gif"
  echo "video $n"
done
