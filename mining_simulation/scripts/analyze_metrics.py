#!/usr/bin/env python3
"""
Comprehensive analysis script for mining simulation test results.
Analyzes CSV metrics from regtest nodes running the timed mining feature.
"""
import csv
import sys
import numpy as np
from datetime import datetime, timedelta


def analyze_node_metrics(csv_file):
    """Analyze metrics from a single node's CSV data."""
    with open(csv_file, 'r') as f:
        reader = csv.DictReader(f)
        data = list(reader)

    timestamps = [int(row['timestamp']) for row in data]
    blocks = [int(row['block_number']) for row in data]
    gas_used = [int(row['gas_used']) for row in data]
    gas_limit = [int(row['gas_limit']) for row in data]
    tx_counts = [int(row['tx_count']) for row in data]

    # Time range
    start_time = datetime.fromtimestamp(timestamps[0])
    end_time = datetime.fromtimestamp(timestamps[-1])
    duration = end_time - start_time

    # Block intervals
    intervals = []
    for i in range(1, len(timestamps)):
        if blocks[i] == blocks[i-1] + 1:
            intervals.append(timestamps[i] - timestamps[i-1])

    intervals = np.array(intervals)

    # Gas usage stats
    total_gas_used = sum(gas_used)
    avg_gas_per_block = np.mean(gas_used)
    blocks_with_gas = [g for g in gas_used if g > 0]
    avg_gas_when_used = np.mean(blocks_with_gas) if blocks_with_gas else 0
    blocks_at_target = sum(1 for g in gas_used if g >= 29000000)  # Near target

    # Transaction stats
    total_txs = sum(tx_counts)
    avg_tx_per_block = np.mean(tx_counts)
    blocks_with_1_tx = sum(1 for t in tx_counts if t == 1)
    blocks_with_many_txs = sum(1 for t in tx_counts if t > 1)

    # Prepare results
    results = {
        'csv_file': csv_file,
        'start_time': start_time,
        'end_time': end_time,
        'duration': duration,
        'total_blocks': len(data),
        'block_range': (blocks[0], blocks[-1]),
        'intervals': {
            'mean': np.mean(intervals),
            'median': np.median(intervals),
            'std': np.std(intervals),
            'min': np.min(intervals),
            'max': np.max(intervals),
            'shape_param': np.mean(intervals) / np.std(intervals),
            'count': len(intervals)
        },
        'gas': {
            'total_used': total_gas_used,
            'avg_per_block': avg_gas_per_block,
            'avg_when_used': avg_gas_when_used,
            'limit': gas_limit[0],
            'utilization_pct': avg_gas_per_block / gas_limit[0] * 100,
            'blocks_at_target': blocks_at_target
        },
        'transactions': {
            'total': total_txs,
            'avg_per_block': avg_tx_per_block,
            'blocks_with_1': blocks_with_1_tx,
            'blocks_with_many': blocks_with_many_txs
        }
    }

    return results


def print_analysis(results):
    """Print formatted analysis results."""
    print(f"\n{'='*60}")
    print(f"Analysis for: {results['csv_file']}")
    print(f"{'='*60}")

    print(f"\n📊 Test Duration: {results['duration']}")
    print(f"   Start: {results['start_time']}")
    print(f"   End:   {results['end_time']}")
    print(f"   Total Blocks: {results['total_blocks']:,}")
    print(f"   Block Range: {results['block_range'][0]} to {results['block_range'][1]}")

    print(f"\n⏱️  Block Interval Statistics:")
    print(f"   Mean:        {results['intervals']['mean']:.2f}s")
    print(f"   Median:      {results['intervals']['median']:.2f}s")
    print(f"   Std Dev:     {results['intervals']['std']:.2f}s")
    print(f"   Min:         {results['intervals']['min']:.2f}s")
    print(f"   Max:         {results['intervals']['max']:.2f}s")
    print(f"   Shape param: {results['intervals']['shape_param']:.3f} (expect ~1.0 for exponential)")

    print(f"\n⛽ Gas Usage Statistics:")
    print(f"   Total Gas Used:       {results['gas']['total_used']:,}")
    print(f"   Average per Block:    {results['gas']['avg_per_block']:,.0f}")
    print(f"   Average (when > 0):   {results['gas']['avg_when_used']:,.0f}")
    print(f"   Gas Limit:            {results['gas']['limit']:,}")
    print(f"   Utilization:          {results['gas']['utilization_pct']:.2f}%")
    print(f"   Blocks at Target:     {results['gas']['blocks_at_target']} ({results['gas']['blocks_at_target']/results['total_blocks']*100:.1f}%)")

    print(f"\n📝 Transaction Statistics:")
    print(f"   Total Transactions:   {results['transactions']['total']:,}")
    print(f"   Average per Block:    {results['transactions']['avg_per_block']:.2f}")
    print(f"   Blocks with 1 tx:     {results['transactions']['blocks_with_1']} ({results['transactions']['blocks_with_1']/results['total_blocks']*100:.1f}%)")
    print(f"   Blocks with >1 tx:    {results['transactions']['blocks_with_many']} ({results['transactions']['blocks_with_many']/results['total_blocks']*100:.1f}%)")


def main():
    if len(sys.argv) < 2:
        print("Usage: analyze_metrics.py <csv_file1> [csv_file2] ...")
        sys.exit(1)

    all_results = []
    for csv_file in sys.argv[1:]:
        try:
            results = analyze_node_metrics(csv_file)
            print_analysis(results)
            all_results.append(results)
        except Exception as e:
            print(f"Error analyzing {csv_file}: {e}")
            continue

    # Comparative summary if multiple files
    if len(all_results) > 1:
        print(f"\n{'='*60}")
        print("COMPARATIVE SUMMARY")
        print(f"{'='*60}")

        for i, r in enumerate(all_results, 1):
            print(f"\nNode {i}: {r['csv_file'].split('/')[-1]}")
            print(f"  Duration:        {r['duration']}")
            print(f"  Blocks:          {r['total_blocks']:,}")
            print(f"  Median Interval: {r['intervals']['median']:.2f}s")
            print(f"  Gas Utilization: {r['gas']['utilization_pct']:.2f}%")
            print(f"  Total TXs:       {r['transactions']['total']:,}")


if __name__ == '__main__':
    main()
