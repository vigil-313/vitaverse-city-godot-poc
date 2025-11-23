# Scale Verification Test - Instructions

## CRITICAL: Test Scale BEFORE rendering OSM data

We're starting from scratch to verify our scale is accurate.

## How to Run the Test

1. **Open `scenes/scale_test.tscn`** in Godot
2. **Run the scene** (F5)
3. **Verify the measurements below**

## What You Should See

### Reference Grid
- White grid lines creating 10m × 10m squares
- Use this to measure everything

### Test Road (dark gray)
- **17m wide** (should span 1.7 grid squares)
- **50m long** (should span 5 grid squares)
- Labeled "ROAD: 17m WIDE (4 lanes)"

### Test Building (tan/brown)
- **20m wide** (2 grid squares)
- **15m deep** (1.5 grid squares)
- **9m tall** (3 floors × 3m)
- Labeled "BUILDING: 20m × 15m × 9m"

### Player (blue character)
- **1.7m tall** (human height)
- Should be positioned at (-10, 1, 10)

## Scale Verification Checklist

Use this to verify scale is correct:

### ✅ Player Scale
- [ ] Player is **1.7m tall** (slightly less than 1 floor/3m)
- [ ] Player is **~1/5 the height of the building** (1.7m vs 9m)
- [ ] Player could fit **~10 times across the road width** (17m / 1.7m ≈ 10)
- [ ] Player is **~1/6 of a grid square** (1.7m in a 10m square)

### ✅ Road Scale
- [ ] Road is **17m wide** (spans 1.7 grid squares)
- [ ] Road looks like it could fit **4 cars side-by-side** (4 lanes)
- [ ] Road is **~10× player width** (4 lanes should be WIDE)
- [ ] Player walking across should take appropriate time

### ✅ Building Scale
- [ ] Building is **20m × 15m footprint** (2 × 1.5 grid squares)
- [ ] Building is **9m tall** (3 floors, each floor taller than player)
- [ ] Building is **~5.3× player height** (9m / 1.7m)
- [ ] Each floor is **~3m** (about 1.8× player height)

## If Scale is WRONG

### Problem: Player looks like a giant
**Cause:** Player model too large OR world too small
**Fix:** Check player.tscn collision capsule height

### Problem: Road looks tiny
**Cause:** Road width calculation wrong
**Fix:** Verify road width = 17m in scale_test.gd

### Problem: Building looks too small
**Cause:** Building height wrong OR coordinate system issue
**Fix:** Verify building height = 9m in scale_test.gd

### Problem: Grid squares don't look like 10m
**Cause:** Coordinate system fundamentally wrong
**Fix:** Check OSM lat/lon conversion math

## Expected Console Output

```
🎯 SCALE TEST: Creating reference grid
  ✅ Grid created: Each square = 10m x 10m
🎯 SCALE TEST: Creating test road
  ✅ Test road: 17m wide × 50m long
     (Should be 4 lanes wide - verify visually)
🎯 SCALE TEST: Creating test building
  ✅ Test building: 20m × 15m × 9m tall
     (3 floors × 3m = 9m total height)
🎯 SCALE VERIFICATION:
  → Player should be 1.7m tall (human height)
  → Player should fit ~10 times in road width (17m)
  → Building should be ~5.3× player height (9m / 1.7m)
  → Each grid square is 10m × 10m
  → If these don't match visually, SCALE IS WRONG
```

## Taking Measurements

1. **Walk the player across the road** - Should take a few seconds for 17m
2. **Stand player next to building** - Building should be ~5× taller
3. **Count grid squares** - Verify road spans 1.7 squares
4. **Walk across a grid square** - Should take ~5-6 seconds at walking speed

## Next Steps

### If Scale is CORRECT ✅
→ Proceed to render ONE road from OSM
→ Verify it matches expected dimensions
→ Then add ONE building
→ Build up carefully from there

### If Scale is WRONG ❌
→ STOP - Fix scale first
→ Report which measurement is off
→ Fix coordinate system/player size
→ Re-test until correct
