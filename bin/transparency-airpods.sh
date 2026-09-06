#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title transparency airpods
# @raycast.mode compact
# @raycast.packageName AirPods
set -euo pipefail
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/airpods-noise-control" transparency
