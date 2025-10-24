#!/bin/bash
# Continuous monitoring script for regtest testing

OUTPUT_DIR="${1:-./test-results}"
INTERVAL="${2:-300}"  # 5 minutes default
NODE_IP="${3:-localhost}"
NODE_RPC="http://${NODE_IP}:4444"

mkdir -p "$OUTPUT_DIR/metrics"
mkdir -p "$OUTPUT_DIR/logs"

METRICS_FILE="$OUTPUT_DIR/metrics/continuous-$(date +%Y%m%d_%H%M%S).csv"

echo "Starting monitoring script with the following parameters:"
echo "OUTPUT_DIR: $OUTPUT_DIR"
echo "INTERVAL: $INTERVAL"
echo "NODE_IP: $NODE_IP"
echo "NODE_RPC: $NODE_RPC"
echo "METRICS_FILE: $METRICS_FILE"

echo "timestamp,block_number,block_hash,gas_used,gas_limit,tx_count,cpu_percent,mem_rss_mb,db_size_mb,thread_count" > "$METRICS_FILE"

# Previous block number
PREV_BLOCK_NUM=0

while true; do
  TIMESTAMP=$(date +%s)

  # Blockchain metrics via RPC
  BLOCK_NUM=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' "$NODE_RPC" | jq -r '.result' | xargs printf "%d")
  
  # If the block number is the same as the previous block number, skip the rest of the loop
  if [ "$BLOCK_NUM" -eq "$PREV_BLOCK_NUM" ]; then
    sleep "$INTERVAL"
    continue
  fi

  # Update the previous block number
  PREV_BLOCK_NUM="$BLOCK_NUM" 
  
  BLOCK_DATA=$(curl -s -X POST -H "Content-Type: application/json" --data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBlockByNumber\",\"params\":[\"0x$(printf %x $BLOCK_NUM)\",false],\"id\":1}" "$NODE_RPC")
  BLOCK_HASH=$(echo "$BLOCK_DATA" | jq -r '.result.hash')
  GAS_USED=$(echo "$BLOCK_DATA" | jq -r '.result.gasUsed' | xargs printf "%d")
  GAS_LIMIT=$(echo "$BLOCK_DATA" | jq -r '.result.gasLimit' | xargs printf "%d")
  TX_COUNT=$(echo "$BLOCK_DATA" | jq -r '.result.transactions | length')

  # System metrics
  SYSTEM_STATS=$(ps aux | grep '[j]ava' | awk '{print \$3,\$6}')
  CPU_PERCENT=$(echo "$SYSTEM_STATS" | awk '{print $1}')
  MEM_RSS_KB=$(echo "$SYSTEM_STATS" | awk '{print $2}')
  MEM_RSS_MB=$((MEM_RSS_KB / 1024))

  # Database size
  DB_SIZE_BYTES=$(du -sb /var/lib/rsk/database/regtest 2>/dev/null | awk '{print \$1}')
  DB_SIZE_MB=$((DB_SIZE_BYTES / 1024 / 1024))

  # Thread count
  THREAD_COUNT=$(ps -eLf | grep -c '[j]ava')

  echo "$TIMESTAMP,$BLOCK_NUM,$BLOCK_HASH,$GAS_USED,$GAS_LIMIT,$TX_COUNT,$CPU_PERCENT,$MEM_RSS_MB,$DB_SIZE_MB,$THREAD_COUNT" >> "$METRICS_FILE"

  sleep "$INTERVAL"
done
