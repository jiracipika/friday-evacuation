#!/bin/bash
# run_ladder.sh — full serial verification ladder for friday-evacuation.
cd /Volumes/HARD/projects/friday-evacuation || exit 1
git diff --check || { echo "diff-check FAILED"; exit 1; }
TESTS="BootTest PlayerChairSmokeTest CharacterRosterSmokeTest HauledSmokeTest ShopSeekSmokeTest PizzaColonySmokeTest TouchControlsSmokeTest ModeSmokeTest NetworkSmokeTest NetworkTwoPeerTest AnnouncerSmokeTest PanicCamSmokeTest LevelClearTest HazardsSmokeTest ThemedFloorsSmokeTest PowerUpSmokeTest PauseMenuSmokeTest AccessibilitySmokeTest RaceModifiersSmokeTest ModifierMenuSmokeTest GhostRacerSmokeTest StatsRoundTripTest VisualDesignSmokeTest WallMaterialsSmokeTest FaceSmokeTest InputPrefsSmokeTest ControlsOverlaySmokeTest SettingsRoundTripTest NormalMapSmokeTest GamepadSupportTest"
overall=0
for t in $TESTS; do
  if [ ! -f "scripts/$t.gd" ]; then
    echo "=== $t MISSING (skipped) ==="
    continue
  fi
  /usr/local/bin/godot --headless --path . --script "scripts/$t.gd" > "/tmp/lad_$t.log" 2>&1
  rc=$?
  if [ $rc -ne 0 ]; then
    echo "=== $t FAILED rc=$rc ==="
    grep -E "FAIL|SCRIPT ERROR" "/tmp/lad_$t.log" | head -4
    overall=1
  else
    echo "=== $t PASS ==="
  fi
done
/usr/local/bin/godot --headless --path . --quit-after 3 > /tmp/boot.log 2>&1
echo "BOOT script errors: $(grep -c 'SCRIPT ERROR' /tmp/boot.log)"
exit $overall
