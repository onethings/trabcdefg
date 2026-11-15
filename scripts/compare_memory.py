#!/usr/bin/env python3
"""Compare two build/memory CSVs column by column.

    scripts/compare_memory.py build/memory/before-*.csv build/memory/after-*.csv

Only meaningful when both runs used the same scenario on the same device. The
point is the plateau and the peak, not the launch ramp: the map engine allocates
its graphics surfaces once, so the first samples are always much lower.
"""
import csv
import glob
import sys

COLUMNS = [
    'total_pss_kb',
    'native_kb',
    'private_other_kb',
    'graphics_kb',
    'code_kb',
    'java_kb',
]

# Anything before this many seconds is the launch ramp, not the scenario.
SKIP_RAMP_SECONDS = 45


def load(path):
    with open(path, newline='') as handle:
        rows = [row for row in csv.DictReader(handle) if row['total_pss_kb'].strip()]
    return rows


def after_ramp(rows):
    kept = [row for row in rows if int(row['elapsed_s']) >= SKIP_RAMP_SECONDS]
    return kept or rows


def stats(rows, column):
    values = [int(row[column]) for row in rows if row[column].strip()]
    if not values:
        return None
    ordered = sorted(values)
    mid = len(ordered) // 2
    median = ordered[mid] if len(ordered) % 2 else (ordered[mid - 1] + ordered[mid]) // 2
    return {'peak': max(values), 'last': values[-1], 'median': median, 'n': len(values)}


def mb(kb):
    return f'{kb / 1024:.0f}'


def main():
    if len(sys.argv) != 3:
        print(__doc__.strip())
        return 1

    labels = ['before', 'after']
    runs = {}
    for label, pattern in zip(labels, sys.argv[1:]):
        matches = sorted(glob.glob(pattern))
        if not matches:
            print(f'no file matches {pattern}')
            return 1
        runs[label] = after_ramp(load(matches[-1]))
        print(f'{label}: {matches[-1]}  samples={len(runs[label])}')

    counts = [len(runs[label]) for label in labels]
    if min(counts) < 5:
        print('warning: fewer than 5 samples after the launch ramp, compare with care')
    if max(counts) > 2 * min(counts):
        print('warning: sample counts differ a lot, the scenarios probably did not match')

    print()
    print(f'{"column":18}{"before median":>15}{"after median":>14}{"delta":>9}{"  |":>3}'
          f'{"before peak":>13}{"after peak":>12}{"delta":>9}')
    for column in COLUMNS:
        before = stats(runs['before'], column)
        after = stats(runs['after'], column)
        if not before or not after:
            continue
        median_delta = (after['median'] - before['median']) / 1024
        peak_delta = (after['peak'] - before['peak']) / 1024
        print(f'{column:18}{mb(before["median"]):>15}{mb(after["median"]):>14}{median_delta:>+9.0f}{"  |":>3}'
              f'{mb(before["peak"]):>13}{mb(after["peak"]):>12}{peak_delta:>+9.0f}')

    print('\nAll figures in MB. Median is the honest statistic: total PSS swings')
    print('by tens of MB between samples while the map loads tiles, so a single')
    print('peak or final sample tells you more about which frame you caught than')
    print('about which build you measured.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
