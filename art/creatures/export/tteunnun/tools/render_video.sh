#!/usr/bin/env bash
# work/frames/<clip>/*.png → renders/<clip>.mp4 (소리 없음, 반복 동작은 두 바퀴) + renders/all_clips.mp4 + renders/sheet.png
set -e
cd "$(dirname "$0")/.."
mkdir -p renders
cp /c/Windows/Fonts/arial.ttf work/arial.ttf; FONT=work/arial.ttf
LIST=work/concat.txt; : > "$LIST"
for c in Idle Walk Run Attack LookAround Hit Death EyeDart Stare; do
  d=work/frames/$c; [ -d "$d" ] || continue
  loop=0; case $c in Idle|Walk|Run|LookAround|EyeDart) loop=1;; esac
  [ $c = Walk ] || [ $c = Run ] && loop=2
  ffmpeg -loglevel error -y -stream_loop $loop -framerate 30 -start_number 0 -i "$d/%04d.png" -an \
    -vf "drawtext=fontfile=$FONT:text='$c':x=16:y=16:fontsize=28:fontcolor=white@0.85" \
    -c:v libx264 -pix_fmt yuv420p -crf 20 renders/$c.mp4
  echo "file '../renders/$c.mp4'" >> "$LIST"
done
ffmpeg -loglevel error -y -f concat -safe 0 -i "$LIST" -an -c copy renders/all_clips.mp4
# 동작마다 가운데 프레임 하나씩 모은 한 장
args=(); n=0
for c in Idle Walk Run Attack LookAround Hit Death EyeDart Stare; do
  d=work/frames/$c; [ -d "$d" ] || continue
  cnt=$(ls $d | wc -l); f=$(ls $d | sed -n "$(( cnt*6/10 + 1 ))p")
  args+=(-i "$d/$f"); n=$((n+1))
done
ffmpeg -loglevel error -y "${args[@]}" -filter_complex "$(for i in $(seq 0 $((n-1))); do printf '[%d]' $i; done)hstack=$n,scale=2400:-1" renders/sheet.png
ls -la renders
