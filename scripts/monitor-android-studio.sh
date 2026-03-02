#!/usr/bin/env bash
# Small helper to inspect Gradle daemons and Java processes for Android Studio
set -euo pipefail

echo "Gradle daemons:"
./gradlew --status 2>/dev/null || echo "Gradle wrapper not found or Gradle not initialized"

echo
echo "Java processes (Android Studio / Gradle):"
ps aux | egrep 'gradle|studio' | egrep -v 'egrep' || true

echo
echo "Top JVM memory usage (requires jcmd):"
if command -v jcmd >/dev/null 2>&1; then
  for pid in $(pgrep -f 'gradle|studio' || true); do
    echo "--- PID: $pid ---"
    jcmd $pid VM.flags || true
  done
else
  echo "jcmd not installed; install JDK tools to use jcmd"
fi
