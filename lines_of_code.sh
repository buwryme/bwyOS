#!/bin/bash

declare -A counts

for ext in ld eixx conf; do
  files=$(find . -type f -name "*.$ext")
  total_lines=0
  for file in $files; do
    lines=$(wc -l < "$file")
    total_lines=$((total_lines + lines))
  done
  counts["$ext"]=$total_lines
done

grand_total=0
printf "%-10s %s\n" "extension" "lines"
printf "%-10s %s\n" "---------" "-----"
for ext in "${!counts[@]}"; do
  printf "%-10s %d\n" "$ext" "${counts[$ext]}"
  grand_total=$((grand_total + counts[$ext]))
done

printf "%-10s %s\n" "---------" "-----"
printf "%-10s %d\n" "total" "$grand_total"
