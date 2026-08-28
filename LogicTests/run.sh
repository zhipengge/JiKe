#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(mktemp -d)/jike-logic-tests"
SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
swiftc -parse-as-library -O -sdk "$SDKROOT" -o "$OUT" \
  "$ROOT/Shared/SharedConstants.swift" \
  "$ROOT/Shared/GtkAccelerator.swift" \
  "$ROOT/Shared/HotkeySpec.swift" \
  "$ROOT/Shared/WindowGeometry.swift" \
  "$ROOT/Shared/SplitLayout.swift" \
  "$ROOT/Shared/QuickOpenParser.swift" \
  "$ROOT/Shared/LinkDetector.swift" \
  "$ROOT/Shared/TabTitle.swift" \
  "$ROOT/Shared/JiKeCommand.swift" \
  "$ROOT/Shared/GuakePalettesData.swift" \
  "$ROOT/Shared/ColorPalette.swift" \
  "$ROOT/Shared/GuakeCustomCommands.swift" \
  "$ROOT/Shared/AppConfig.swift" \
  "$ROOT/Shared/SessionStore.swift" \
  "$ROOT/Shared/ShellLaunch.swift" \
  "$ROOT/Shared/UserPath.swift" \
  "$ROOT/Shared/MacPasteInsertion.swift" \
  "$ROOT/Shared/TerminalAppearance.swift" \
  "$ROOT/LogicTests/LogicTests.swift"
"$OUT"
