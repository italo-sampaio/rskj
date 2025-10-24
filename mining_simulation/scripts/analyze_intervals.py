#!/usr/bin/env python3
import sys
import csv
import numpy as np
import matplotlib.pyplot as plt
from scipy import stats


def analyze_block_intervals(metrics_file, output_dir):
    timestamps = []
    blocks = []

    with open(metrics_file, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            timestamps.append(int(row['timestamp']))
            blocks.append(int(row['block_number']))

    print(f"Timestamps: {timestamps}")
    print(f"Blocks: {blocks}")

    # Calculate intervals
    intervals = []
    for i in range(1, len(timestamps)):
        if blocks[i] == blocks[i-1] + 1:  # Consecutive blocks
            interval = timestamps[i] - timestamps[i-1]
            intervals.append(interval)

    intervals = np.array(intervals)

    # Statistics
    mean_interval = np.mean(intervals)
    median_interval = np.median(intervals)
    std_interval = np.std(intervals)

    print(f"Mean interval: {mean_interval:.2f} seconds")
    print(f"Median interval: {median_interval:.2f} seconds")
    print(f"Std deviation: {std_interval:.2f} seconds")
    print(f"Min interval: {np.min(intervals):.2f} seconds")
    print(f"Max interval: {np.max(intervals):.2f} seconds")

    # Test for exponential distribution
    # Exponential has mean = std for normalized distribution
    shape_param = mean_interval / std_interval
    print(f"Shape parameter (should be ~1.0 for exponential): {shape_param:.3f}")

    # Histogram
    plt.figure(figsize=(12, 6))
    plt.hist(intervals, bins=50, density=True, alpha=0.7, label='Observed')

    # Overlay theoretical exponential
    x = np.linspace(0, max(intervals), 100)
    rate = 1.0 / mean_interval
    plt.plot(x, rate * np.exp(-rate * x), 'r-', label='Exponential fit')

    plt.xlabel('Block Interval (seconds)')
    plt.ylabel('Probability Density')
    plt.title(f'Block Interval Distribution (median={median_interval:.1f}s)')
    plt.legend()
    plt.grid(True, alpha=0.3)
    plt.savefig(f'{output_dir}/interval_distribution.png', dpi=150)
    print(f"Saved histogram to {output_dir}/interval_distribution.png")


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: analyze_intervals.py <metrics_file> [output_dir]")
        sys.exit(1)

    metrics_file = sys.argv[1]
    output_dir = sys.argv[2] if len(sys.argv) > 2 else './test-results'

    analyze_block_intervals(metrics_file, output_dir)
