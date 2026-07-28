#!/bin/bash
cd "$(dirname "$0")"
pkill -x OpenWisprFlow 2>/dev/null
sleep 0.5
# Launch through the .app bundle (not the bare binary) so macOS privacy (TCC)
# reads the usage-description keys — a bare-binary launch SIGABRTs on first
# speech/mic access with a "missing usage description" TCC violation.
: > /tmp/owf.log
open build/OpenWisprFlow.app --stderr /tmp/owf.log
echo "App launched (bundle). PID: $(pgrep -x OpenWisprFlow)"
echo "Logs will be at /tmp/owf.log"
echo "Press Start in the app, speak, then press Stop."
echo "Then run: cat /tmp/owf.log"
