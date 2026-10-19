#!/bin/sh
set -eu
cd -- "$(dirname -- "$0")"
exec ./PocketFrameNative.arm64 "$@"
