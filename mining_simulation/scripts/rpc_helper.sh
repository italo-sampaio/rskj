#!/bin/bash
# Quick RPC commands for testing

NODE_IP="${1:-localhost}"
NODE_RPC="http://${NODE_IP}:4444"

case "${2:-help}" in
  block)
    curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' "$NODE_RPC" | jq
    ;;
  latest)
    curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest",true],"id":1}' "$NODE_RPC" | jq
    ;;
  peers)
    curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' "$NODE_RPC" | jq
    ;;
  txpool)
    curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"txpool_status","params":[],"id":1}' "$NODE_RPC" | jq
    ;;
  *)
    echo "Usage: rpc_helper.sh <node_ip> <command>"
    echo "Commands: block, latest, peers, txpool"
    ;;
esac
