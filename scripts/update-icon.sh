#!/bin/zsh
set -euo pipefail
if [[ $# -ne 1 ]]; then
  print -u2 'Usage: ./scripts/update-icon.sh /path/to/square-master.png'
  exit 1
fi
icon_source="${1:A}"
icon_destination="${0:A:h:h}/Sources/BetterNote/Resources/Assets.xcassets/AppIcon.appiconset"
for icon_points in 16 32 128 256 512; do
  for icon_scale in 1 2; do
    icon_pixels=$((icon_points * icon_scale))
    sips -s format png -z "$icon_pixels" "$icon_pixels" "$icon_source" --out "$icon_destination/icon-${icon_points}@${icon_scale}x.png" >/dev/null
  done
done
icon_work="${0:A:h:h}/build.noindex/IconAssets/BetterNote.iconset"
mkdir -p "$icon_work"
for icon_points in 16 32 128 256 512; do
  cp "$icon_destination/icon-${icon_points}@1x.png" "$icon_work/icon_${icon_points}x${icon_points}.png"
  cp "$icon_destination/icon-${icon_points}@2x.png" "$icon_work/icon_${icon_points}x${icon_points}@2x.png"
done
iconutil -c icns "$icon_work" -o "${0:A:h:h}/Sources/BetterNote/Resources/BetterNote.icns"
print 'Updated all macOS icon sizes and direct ICNS bundle resource.' 
