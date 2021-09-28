#!/bin/bash
set -e
cd "$(dirname "$0")"
source config

rm -rf "$OUTPUT_DIR/include" || true
rm -rf "$OUTPUT_DIR/share" || true
rm -rf "$OUTPUT_DIR/lib/"*.a || true
rm -rf "$OUTPUT_DIR/lib/"*.la || true
rm -rf "$OUTPUT_DIR/bin/"llvm-config* || true
rm -rf "$OUTPUT_DIR/bin/apple-darwin"* || true
