#!/bin/bash
# run_ladder.sh — full serial verification ladder for friday-evacuation.
# Runs from the repo that contains it (SSD checkout or HDD original).
cd "$(dirname "$0")/.." || exit 1
git diff --check || { echo "diff-check FAILED"; exit 1; }
TESTS="BootTest HeroAssemblySmokeTest SplashGateTest PlayerChairMechanicsSmokeTest JumpForgivenessTest GraphicsPassSmokeTest MenuLayoutSmokeTest ChairSkinSmokeTest CharacterRosterSmokeTest HauledSmokeTest ShopSeekSmokeTest PizzaColonySmokeTest TouchControlsSmokeTest ModeSmokeTest NetworkSmokeTest NetworkTwoPeerTest LanAvatarSyncTest AnnouncerSmokeTest PanicCamSmokeTest LevelClearTest CheckpointBotTest SkinBotSanityTest HazardsSmokeTest ThemedFloorsSmokeTest PowerUpSmokeTest PauseMenuSmokeTest AccessibilitySmokeTest Phase8BAccessTest RaceModifiersSmokeTest ModifierMenuSmokeTest GhostRacerSmokeTest StatsRoundTripTest VisualDesignSmokeTest WallMaterialsSmokeTest FaceSmokeTest BindingsSmokeTest InputPrefsSmokeTest ControlsOverlaySmokeTest SettingsRoundTripTest NormalMapSmokeTest PropMaterialsSmokeTest LevelLayoutSmokeTest PreMatchModalSmokeTest GamepadSupportTest FloorCullingTest ArtLightingTest ArtMaterialsTest ArtSurfaceReadabilityTest ArtPropsTest ArtHUDTest"
overall=0
for t in $TESTS; do
  if [ ! -f "scripts/$t.gd" ]; then
    echo "=== $t MISSING (skipped) ==="
    continue
  fi
  /usr/local/bin/godot --headless --path . --script "scripts/$t.gd" -- --test-mode > "/tmp/lad_$t.log" 2>&1
  rc=$?
  if [ $rc -ne 0 ]; then
    echo "=== $t FAILED rc=$rc ==="
    grep -E "FAIL|SCRIPT ERROR" "/tmp/lad_$t.log" | head -4
    overall=1
  else
    echo "=== $t PASS ==="
  fi
done
/usr/local/bin/godot --headless --path . --quit-after 3 -- --test-mode > /tmp/boot.log 2>&1
echo "BOOT script errors: $(grep -c 'SCRIPT ERROR' /tmp/boot.log)"
exit $overall
