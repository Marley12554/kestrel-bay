# Godot migration design record

These were the requests that guided the migration from the HTML game. The [project readme](README.md) describes the runnable release. The list below records the design discussion and its original targets.

## Latest confirmed adjustments

- Make engine audio clearly louder without returning to the piercing siren-like
  engine sound. Preserve distance attenuation and sensible overlapping audio.
- Sports cars, including the striped model, should appear **25% as often as now**:
  a **75% frequency reduction**, not a 25% reduction. Do not reduce total traffic.
- Shift joins Space/X as a held vehicle handbrake; retains sprint on foot.

## World and simulation foundations

- Repair bridge approach junctions with flat aprons and proper full-width vehicle
  clearance; do not hide intersecting ramps by removing collisions.
- Coherent vehicle movement/contact physics, low-speed settling, less bounce,
  persistent obstacle passing/yielding/rerouting, no wrong-way reversing journeys.
- Pedestrians avoid vehicles/wrecks, animate actual movement, and seek safety
  while danger persists rather than calling police and resuming a casual walk.
- Diagnose lighting bands (shadow bias/filtering and overlapping surfaces), not
  merely increase brightness. Improve performance without harsh facade pop-in.

## Encounters and vehicles

- Shared player/AI boat acceleration, steering and speed profiles: same model,
  same capabilities. No pursuit-only speed bonus.
- Full visible-hull collision, swept fast-contact checks, stable multi-boat
  contacts, solid decks/cockpits, deliberate boarding points and real cover.
- Marine roles/spacing/interception, independently aimed searchlights, targetable
  captain/officer crews; armed officer at higher escalation, restrained concurrent
  gunfire. Captain reacts to injured crew/boarding and cannot pilot remotely.
- Helicopters remain unarmed spotters. Higher moving search/orbits, visible night
  searchlight, response to incoming fire, tail rotor, irreversible crash lifecycle.
- Incoming fire prompts directional investigation and real cover, without
  revealing an unseen shooter through cover or underwater.
- Occupied-car theft requires opportunity and driver/crew reactions; starting the
  timing game must not freeze the driver. Keep lockpicking for appropriate empty
  vehicles and do not restore frustrating fast timing.
- Revisit speeds AND acceleration with consistent physical units. The previously
  proposed speed table remains a proposal, not an approved tuning specification.
  Make the existing mph readout prominent.
- Spreading fire, faster critical red pulses, restrained pressure-like hiss and
  whistle (no screech), substantial explosions with matching falloff/occlusion,
  persistent smoke that obscures both AI and player, sensible charred wreck parts.

## Water

- Shared visible wave/buoyancy model, sheltered harbor vs open-ocean conditions,
  restrained swimming camera, wakes/spray/shore foam within browser performance.
- Slow passive sinking when idle; upward strokes with Space and directional swim.
  Active swimming largely counters sinking; oxygen follows the actual head depth.

## Prison and navigation

- Regenerate the prison as a coherent fortified facility with gatehouse/sallyport,
  meaningful cell wings, service areas, patrols and infiltration routes.
- Dynamic lockdown after discovery, not an instant mission-failed screen.
- Armed intruders receive appropriate guard/security-vehicle reactions.
- Mode-aware mainland dock navigation before water travel; one earned exterior
  prison dock checkpoint, no arbitrary interior/panel checkpoints; migrate saves.

## Presentation

- Wanted display: custom faceted engraved metal stars, brass active/tarnished
  inactive, stronger presence without the rounded card or police-state narration.
  Slow visual search pulse; retain map, navigation and police blips.
- Clearly emissive alternating red/blue lightbars with bounded environmental light
  at night; no white bloom blobs.
- Fuller spatial siren wail/occasional yelp, distance/occlusion and bounded source
  mixing. Stop/pause audio correctly; no perpetual synthetic alarm oscillator.
