#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
if command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate
fi
xcodebuild -project BetterNote.xcodeproj -scheme BetterNote -configuration Release -derivedDataPath build.noindex build CODE_SIGNING_ALLOWED=NO
codesign --force --sign - build.noindex/Build/Products/Release/BetterNote.app
printf '\nBuilt: %s/build.noindex/Build/Products/Release/BetterNote.app\n' "$PWD"
