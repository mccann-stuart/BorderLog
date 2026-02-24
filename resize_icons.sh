#!/bin/bash
IMAGE="/Users/mccannstuart/.gemini/antigravity/brain/421e39c8-6fb8-42a0-8ab1-75d5707cfc93/media__1771930888706.png"
DEST="Learn/Assets.xcassets/AppIcon.appiconset"

# sizes array
declare -A SIZES=(
  ["AppIcon-20.png"]="20"
  ["AppIcon-29.png"]="29"
  ["AppIcon-40.png"]="40"
  ["AppIcon-58.png"]="58"
  ["AppIcon-60.png"]="60"
  ["AppIcon-76.png"]="76"
  ["AppIcon-80.png"]="80"
  ["AppIcon-87.png"]="87"
  ["AppIcon-120.png"]="120"
  ["AppIcon-152.png"]="152"
  ["AppIcon-167.png"]="167"
  ["AppIcon-180.png"]="180"
  ["AppIcon-1024.png"]="1024"
)

for file in "${!SIZES[@]}"; do
  dim="${SIZES[$file]}"
  sips -z $dim $dim "$IMAGE" --out "$DEST/$file" > /dev/null
done
echo "Icons resized successfully"
