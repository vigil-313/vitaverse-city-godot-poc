#!/bin/bash

# Fetch COMPLETE OSM data for Seattle South Lake Union
# Gets ALL tags with FULL detail - nothing filtered out
#
# This queries OpenStreetMap's Overpass API for:
# - Buildings: ALL tags (colors, materials, architecture, roofs, etc.)
# - Roads: ALL tags (lanes, surface, width, etc.)
# - Natural features: Parks, water, etc.
# - All metadata and attributes
#
# Output: data/osm_complete.json with full OSM data

echo "🌍 Fetching COMPLETE OpenStreetMap data for All of Seattle..."
echo ""
echo "   📍 Area: All of Seattle, WA (Georgetown to Northgate)"
echo "   🏢 Getting: Buildings with ALL attributes"
echo "   🛣️  Getting: Roads with ALL attributes"
echo "   🌳 Getting: Parks, water, natural features"
echo "   📊 Mode: FULL metadata (out meta)"
echo ""

# All of Seattle bounding box
# Coordinates: [south, west, north, east]
SOUTH="47.495"   # Georgetown/South Park
WEST="-122.436"  # West Seattle/Alki
NORTH="47.734"   # Northgate
EAST="-122.224"  # Lake Washington

# Overpass API endpoint (using main server)
API="https://overpass-api.de/api/interpreter"

echo "📝 Building Overpass QL query..."

# Create comprehensive Overpass QL query
# Using 'out meta' to get ALL tags and metadata
cat > /tmp/osm_complete_query.ql << EOF
[out:json][timeout:120];
(
  // ========================================
  // BUILDINGS - Get ALL building data
  // ========================================
  way["building"]($SOUTH,$WEST,$NORTH,$EAST);

  // Building relations (multi-part buildings)
  relation["building"]($SOUTH,$WEST,$NORTH,$EAST);

  // ========================================
  // ROADS & HIGHWAYS - Get ALL road data
  // ========================================
  way["highway"]($SOUTH,$WEST,$NORTH,$EAST);

  // ========================================
  // NATURAL FEATURES & WATER
  // ========================================
  way["natural"]($SOUTH,$WEST,$NORTH,$EAST);
  way["natural"="water"]($SOUTH,$WEST,$NORTH,$EAST);
  way["leisure"]($SOUTH,$WEST,$NORTH,$EAST);
  way["landuse"]($SOUTH,$WEST,$NORTH,$EAST);
  way["waterway"]($SOUTH,$WEST,$NORTH,$EAST);

  // Get complete water relations (even if members extend outside bbox)
  relation["natural"]($SOUTH,$WEST,$NORTH,$EAST);
  relation["natural"="water"]($SOUTH,$WEST,$NORTH,$EAST);
  relation["waterway"]($SOUTH,$WEST,$NORTH,$EAST);

  // ========================================
  // AMENITIES & POIs
  // ========================================
  way["amenity"]($SOUTH,$WEST,$NORTH,$EAST);
  node["amenity"]($SOUTH,$WEST,$NORTH,$EAST);
);

// Output with FULL metadata - gets ALL tags
out meta;

// CRITICAL: Get ALL members of relations (even outside bbox)
// Then get ALL nodes of those members (complete geometry)
>;
out skel qt;
EOF

echo "✅ Query created"
echo ""
echo "📡 Querying Overpass API..."
echo "   ⏱️  This may take 30-60 seconds..."
echo ""

# Fetch the data with progress indicator
curl -X POST \
  --progress-bar \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "data@/tmp/osm_complete_query.ql" \
  "$API" \
  -o "../data/osm_complete.json" 2>&1 | \
  while IFS= read -r line; do
    echo "   $line"
  done

# Check if successful
if [ $? -eq 0 ] && [ -f "../data/osm_complete.json" ]; then
  echo ""
  echo "✅ SUCCESS! OSM data downloaded"
  echo ""

  # Verify it's valid JSON and get stats
  if command -v jq &> /dev/null; then
    echo "📊 Data Statistics:"
    echo ""

    TOTAL=$(jq '.elements | length' ../data/osm_complete.json 2>/dev/null)
    if [ -n "$TOTAL" ]; then
      echo "   📦 Total elements: $TOTAL"

      BUILDINGS=$(jq '[.elements[] | select(.tags.building)] | length' ../data/osm_complete.json 2>/dev/null)
      echo "   🏢 Buildings: $BUILDINGS"

      ROADS=$(jq '[.elements[] | select(.tags.highway)] | length' ../data/osm_complete.json 2>/dev/null)
      echo "   🛣️  Roads/paths: $ROADS"

      PARKS=$(jq '[.elements[] | select(.tags.leisure)] | length' ../data/osm_complete.json 2>/dev/null)
      echo "   🌳 Parks/leisure: $PARKS"

      WATER=$(jq '[.elements[] | select(.tags.natural=="water" or .tags.waterway)] | length' ../data/osm_complete.json 2>/dev/null)
      echo "   💧 Water features: $WATER"

      echo ""
      echo "📋 Sample building with ALL tags:"
      echo ""
      jq '.elements[] | select(.tags.building and .tags.name) | {name: .tags.name, tags: .tags} | @json' ../data/osm_complete.json 2>/dev/null | head -1 | jq '.' 2>/dev/null

    fi
  else
    echo "   ℹ️  Install 'jq' to see detailed statistics"
  fi

  FILE_SIZE=$(ls -lh ../data/osm_complete.json | awk '{print $5}')
  echo ""
  echo "💾 File saved: data/osm_complete.json ($FILE_SIZE)"
  echo ""
  echo "🎉 Complete! Ready to build detailed 3D city."

else
  echo ""
  echo "❌ ERROR: Failed to fetch OSM data"
  echo ""
  echo "Possible issues:"
  echo "  • No internet connection"
  echo "  • Overpass API timeout"
  echo "  • Query syntax error"
  echo ""
  echo "Try again in a few minutes (Overpass API may be busy)"
  exit 1
fi

# Clean up
rm /tmp/osm_complete_query.ql

echo ""
