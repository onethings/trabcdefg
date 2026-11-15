#!/usr/bin/env bash
# Samples an app's PSS from Android's own accounting so a memory change can be
# compared before/after on the same device and the same scenario.
#
#   scripts/measure_memory.sh <label> [interval_seconds] [package] [duration_seconds]
#
# duration_seconds 0 (the default) samples until Ctrl-C. Either way the run ends
# with a CSV in build/memory/ and a slope summary (MB/min) on stdout.
set -uo pipefail

LABEL=${1:?usage: measure_memory.sh <label> [interval_seconds] [package] [duration_seconds]}
INTERVAL=${2:-5}
PKG=${3:-com.example.trabcdefg}
DURATION=${4:-0}

ADB=${ADB:-adb}
if ! command -v "$ADB" >/dev/null 2>&1; then
  ADB="$HOME/Library/Android/sdk/platform-tools/adb"
fi
if ! "$ADB" get-state >/dev/null 2>&1; then
  echo "no device: $ADB get-state failed" >&2
  exit 1
fi

OUT_DIR=build/memory
mkdir -p "$OUT_DIR"
OUT="$OUT_DIR/$LABEL-$(date +%Y%m%d-%H%M%S).csv"
printf 'elapsed_s,java_kb,native_kb,code_kb,stack_kb,graphics_kb,private_other_kb,system_kb,total_pss_kb,mem_available_kb\n' > "$OUT"

# Columns: java,native,code,stack,graphics,private_other,system,total (all KB).
# "system" is an awk builtin, hence sysk.
read_sample() {
  "$ADB" shell dumpsys meminfo "$PKG" 2>/dev/null | awk '
    # Labels are one word ("Code:") or two ("Java Heap:"), the row carries PSS
    # first and RSS second, and recent Android reads "TOTAL PSS:" where older
    # ones read "TOTAL:". So take the first number after every label.
    function num(  i) {
      for (i = 2; i <= NF; i++) if ($i ~ /^[0-9]+$/) return $i
      return ""
    }
    /App Summary/ { inapp = 1; next }
    inapp && /^ *Java Heap:/     { java = num() }
    inapp && /^ *Native Heap:/   { native = num() }
    inapp && /^ *Code:/          { code = num() }
    inapp && /^ *Stack:/         { stack = num() }
    inapp && /^ *Graphics:/      { graphics = num() }
    inapp && /^ *Private Other:/ { other = num() }
    inapp && /^ *System:/        { sysk = num() }
    inapp && /^ *TOTAL/          { total = num(); inapp = 0 }
    END {
      if (total == "" || java == "" || native == "") { print "NA"; exit }
      printf "%s,%s,%s,%s,%s,%s,%s,%s\n", java, native, code, stack, graphics, other, sysk, total
    }'
}

mem_available() {
  "$ADB" shell cat /proc/meminfo 2>/dev/null | awk '/^MemAvailable:/ { print $2; exit }'
}

finish() {
  echo
  awk -F, '
    NR == 2 { for (i = 1; i <= NF; i++) first[i] = $i; fs = $1; rows = 1 }
    NR > 2  { rows = NR - 1; ls = $1; for (i = 1; i <= NF; i++) last[i] = $i }
    END {
      if (rows < 2) { print "not enough samples for a slope"; exit }
      span = ls - fs
      if (span <= 0) { print "samples share a timestamp, slope undefined"; exit }
      printf "%-18s %10s %10s %12s\n", "column", "first(KB)", "last(KB)", "MB/min"
      split("private_other_kb java_kb native_kb graphics_kb total_pss_kb", names, " ")
      split("7 2 3 6 9", cols, " ")
      for (k = 1; k <= 5; k++) {
        i = cols[k]
        delta = last[i] - first[i]
        printf "%-18s %10d %10d %+12.2f\n", names[k], first[i], last[i], (delta / 1024) * 60 / span
      }
      printf "\nsamples=%d span=%ds (first sample at %ss)\n", rows, span, fs
    }' "$OUT"
  echo "csv: $OUT"
  exit 0
}

echo "sampling $PKG every ${INTERVAL}s -> $OUT"
if [ "$DURATION" -gt 0 ]; then
  echo "duration ${DURATION}s"
else
  echo "press Ctrl-C when the scenario is done"
fi

trap 'finish' INT TERM
START=$(date +%s)
while true; do
  NOW=$(date +%s)
  if [ "$DURATION" -gt 0 ] && [ "$((NOW - START))" -ge "$DURATION" ]; then
    break
  fi
  ROW=$(read_sample)
  if [ "$ROW" = "NA" ]; then
    echo "  $((NOW - START))s  no running process for $PKG"
  else
    printf '%s,%s,%s\n' "$((NOW - START))" "$ROW" "$(mem_available)" >> "$OUT"
    echo "  $((NOW - START))s  total=$(printf '%s' "$ROW" | cut -d, -f8)KB"
  fi
  sleep "$INTERVAL"
done

finish
