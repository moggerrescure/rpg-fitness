#!/bin/bash
ASSETS_DIR="/Users/borisserzhanovich/projects/rpg-fitness/rpg-tracker/rpg-tracker/Assets.xcassets"
mkdir -p "$ASSETS_DIR"

import_image() {
    local NAME=$1
    local IMG_PATH=$2
    local DIR="$ASSETS_DIR/$NAME.imageset"
    
    mkdir -p "$DIR"
    cp "$IMG_PATH" "$DIR/${NAME}.png"
    
    cat << 'JSON' > "$DIR/Contents.json"
{
  "images" : [
    {
      "filename" : "FILENAME.png",
      "idiom" : "universal",
      "scale" : "1x"
    },
    {
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "idiom" : "universal",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON
    sed -i '' "s/FILENAME/${NAME}/g" "$DIR/Contents.json"
}

import_image "avatar_goblin" "/Users/borisserzhanovich/.gemini/antigravity-ide/brain/62867a23-2261-411d-9ebb-843f54beda6c/avatar_goblin_1781981840367.png"
import_image "avatar_orc" "/Users/borisserzhanovich/.gemini/antigravity-ide/brain/62867a23-2261-411d-9ebb-843f54beda6c/avatar_orc_1781981873968.png"
import_image "avatar_dragon" "/Users/borisserzhanovich/.gemini/antigravity-ide/brain/62867a23-2261-411d-9ebb-843f54beda6c/avatar_dragon_1781981910632.png"

echo "Assets imported."
