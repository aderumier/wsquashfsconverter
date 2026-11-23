#!/bin/bash
# saveredo.sh: re-run savedir.py on the stored run lists (after a rule change) and repack the images whose lines changed
. "$(dirname "$0")/env.sh"
LOG="$S/savescan.tsv"; cd "$P"
redo=()
while IFS=$'\t' read -r g res old conf; do
  [[ "$res" == added || "$res" == none ]] || continue
  [[ "$conf" == *"by hand"* || "$conf" == *"exe strings"* || "$conf" == *"existing save folder"* ]] && continue
  u="$S/upper_$(echo "$g" | tr ' /' '__').txt"; [[ -f "$u" ]] || continue
  out=$(python3 -I "$T/savedir.py" "$u"); lines=$(echo "$out" | grep -E '^SAVE(DIR|FILES)=' | tr '\n' ' ')
  [[ "${lines% }" == "${old% }" ]] && continue
  [[ -z "$lines" && "$res" == none ]] && continue
  echo "$g: [$old] -> [$lines]"
  [[ -n "${DRY:-}" ]] && continue
  sudo unsquashfs -q -d "$g.wine" "$g.wsquashfs" >/dev/null 2>&1 && sudo chown -R "$(id -u):$(id -g)" "$g.wine"
  A="$g.wine/autorun.cmd"
  { tr -d '\r' < "$A" | grep -vE '^SAVE(DIR|FILES)='; echo "$out" | grep -E '^SAVE(DIR|FILES)='; } > "$A.new" && mv "$A.new" "$A"
  grep -vF "$g	" "$LOG" > "$LOG.new"; mv "$LOG.new" "$LOG"
  printf '%s\t%s\t%s\t%s\n' "$g" "$([[ -n "$lines" ]] && echo added || echo none)" "$lines" "$(echo "$out" | sed -n 's/^# confidence //p')" >> "$LOG"
  redo+=("$g")
done < <(cat "$LOG")
(( ${#redo[@]} )) && "$T/repack.sh" "$P" "${redo[@]}"
