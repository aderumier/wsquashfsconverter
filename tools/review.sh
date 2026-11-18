#!/bin/bash
# review.sh k...: one image, a row per slot with 4 frames
. "$(dirname "$0")/env.sh"
rows=()
for k in "$@"; do
  g=$(grep -m1 "^SLOT=" $S/slot$k.out 2>/dev/null | sed 's/.*GAME=//')
  fr=(); for t in 020 040 055 070; do f=$S/shots$k/$t.png; [[ -f $f ]] || f=$(ls $S/shots$k/*.png 2>/dev/null | tail -1); [[ -f $f ]] && fr+=("$f"); done
  [[ ${#fr[@]} -eq 0 ]] && continue
  montage "${fr[@]}" -geometry 200x112+1+1 -tile 4x $S/row$k.png
  magick $S/row$k.png -gravity West -background white -splice 110x0 -pointsize 11 -annotate +2+0 "$k $g" $S/row$k.png
  rows+=($S/row$k.png)
done
magick "${rows[@]}" -append $S/review.jpg && echo $S/review.jpg
