#!/usr/bin/env bash
# Copy the fixture voice data into the eval workspace, the only place the agent can read.
set -euo pipefail
cp -R "$(dirname "$0")/../voice" ./voice
