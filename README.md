# Kestrel Bay

A standalone WebGL island-city sandbox. First person on foot, third person in vehicles. No install, server, external assets, or package dependencies.

**[Play](https://Marley12554.github.io/kestrel-bay/)** · **[Source](https://github.com/Marley12554/kestrel-bay)**

## Play locally

Open `Kestrel Bay.html` in a desktop browser with WebGL enabled. Click **Enter the Bay**, then click the game to capture the mouse. Press Escape to release it. All operations are unlocked and accepted explicitly from the map; completed jobs can be replayed. The next job is never automatically assigned.

| Control | Action |
| --- | --- |
| WASD / mouse | Move / look; steer in a car |
| Shift | Sprint; vehicle boost |
| Space | Jump; vehicle boost |
| C | Crouch |
| Water | WASD swims in the direction you look; look down/up and press W to dive/surface; Space rises and jumps out |
| E | Open doors, use objects, begin vehicle entry or leave a vehicle |
| Vehicle theft | Click / Space / E in the green zone, three rounds; Escape cancels. Misses, damage or moving away cancel immediately |
| 1 / H | Unarmed / holster on foot; H honks while driving |
| 2 / 3 / 4 / 5 | Pistol / shotgun / carbine / tools |
| Mouse wheel | Cycle owned equipment |
| Left click / J / R | Fire / alternate fire key / reload |
| X | Handbrake |
| M | Map and operations; click the map to set a waypoint |
| Helicopter | WASD movement; E/Q altitude; mouse heading; F board/exit |
| Plane | W/S throttle; A/D rudder; mouse heading/pitch; automatic gear; F board/exit |

Touch controls are also available. Shotguns, carbines, supplies, bypass tools, repairs, and vehicle deliveries can be bought at suppliers. The free starter is a slow compact in an off-street café bay. Striped Interceptors must be found or bought.

## This pass

- Meridian occupies its own island, joined to the mainland by two elevated bridges. The organized center connects to a diagonal theater district, Civic Circle, public courts, mixed-height shore neighborhoods, the eastern wooded promenade, and working docks. The city and mainland use over 250 generated buildings with direct street or courtyard access.
- Building rooms stay in the building's footprint and world coordinates. Floors, elevator shafts and moving platforms, door locks, transparent breakable windows, occupied guest rooms, and exterior fire stairs are physical. All generated buildings are enterable; tall buildings have usable floors rather than off-map rooms.
- Hotels, apartments, offices, cafés, restaurants, shops, garages, warehouses, civic buildings, and prison spaces use different modular layouts. These are procedural low-poly interiors, not individually hand-authored rooms.
- Normal car profiles restore the pre-nerf values. Cruisers have 15% more unboosted top speed than the fastest ordinary car. The striped Interceptor has better steering and remains 20% faster than a cruiser. Its boost improves acceleration without raising that speed ceiling. Sprint is 135 world units/s, up from 100.
- Drivers and pedestrians report crimes. Reports from the same incident share severity; killing a witness cannot retract an already received report. Cameras, police sight and a dispatched helicopter can maintain contact. A sustained crime-free period outside observation is still necessary to lose heat.
- Dispatch keeps inbound cruisers alive throughout their road journey and mobilizes available patrols beyond the immediate neighborhood. Nearby patrols still react when distant units are assigned. Both dock approach lanes remain clear of cargo stacks.
- Pursuing cruisers can leave roads, reverse out of congestion, deploy officers, and pick their officers back up. Officers traverse exterior stairs and breach room doors. One ground unit can cover an upper-floor escape while others pursue. Faster escapes at higher heat can bring a spotter helicopter and physical spike strips.
- Water uses actual body and camera depth, an opaque surface, a seabed, blue distance fog, and oxygen while submerged. Letting go holds depth; Q no longer fakes a dive. Space provides a water exit jump. Marina piers and causeways have physical slabs, and bridge rescue ladders provide a route back up to the sidewalk.
- Vehicle collision damage uses velocity into the obstacle, so a glancing scrape does not count as a full-speed crash. Engine damage produces smoke; a critical engine/wreck burns visibly with a ten-second exit window. Burning or flooded vehicles permit an emergency exit. Explosions account for height, and flooded cars sink rather than standing on the water.
- Persistent patrols occupy the bridge approaches before a chase starts. Dispatch assigns a tail, an intercept, containment and reserve positions. A unit holds the final bridge approach before the road splits, with physical spike strips at high heat. New reinforcements enter from land with at least eight seconds of possible closing time; whole-car camera visibility, free-look and recent views are checked. Helicopters enter from ahead and can keep pace with a fast escape. Surfacing exposes the head again; officers track swimmers from the bridge/shore and cannot see through the water surface.
- The hotbar starts unarmed. Drawing a gun near a patrol officer draws attention. Shotguns and carbines are purchasable and have distinct models, ammunition, fire rates, and reloads.
- Bridge joins preserve pursuit speed, ramps have solid undersides, and bridge/fire escape guardrails prevent walking off. Moderate-speed PIT attempts require physical contact and are disabled on bridges. Reboarded crews can dismount again.
- Engine audio is a quiet, low combustion note with gear changes. Ambient horns are short, local, limited across traffic and used once per direct obstruction. Spike hits give a distinct burst of air, a large alert, persistent tire status, bare gray wheel rims and moving sparks. Repairs restore tires and cabin glass.
- Civilian traffic passes stationary obstructions when the opposing lane is clear, then merges into a safe gap while keeping its original route. It waits when passing is unsafe. Cruisers pull close around a stopped car before deploying; an officer handles extraction while others cover, and repeated window hits can expose the occupant.
- Opening the map suspends the audio context, including sirens, engines and sound-effect tails. Closing it resumes audio.
- Officers notice exposed suspects across open ground and use two simultaneous shooters, observed-motion aiming, short bursts and reloads. Other officers close or flank. A one-star unarmed suspect is approached for arrest. Stationary or creeping vehicles can be approached at a safe door and the driver physically pulled out after a visible, interruptible grab; accelerating breaks the grab.
- Stealing an unowned vehicle takes three increasingly tight timing rounds while the world keeps running. Successful entry visibly ejects actual occupants before boarding; a stolen cruiser leaves its officers outside and alert. Starter, purchased and already-owned vehicles stay quick to enter. Horns use sustained dual tones.
- Burning vehicles pulse red increasingly quickly and display the remaining exit time, in addition to flames and smoke.
- Arrest progress recovers while in a vehicle. Evidence interactions are gated to the relevant accepted operation and their markers clear after completion. Seven main operation stage paths remain playable.

## Hotel route to try

Set a map waypoint to **Mariner Grand** in Meridian. Open its north entrance, walk into reception, and use the elevator in the southwest part of the lobby. Choose a guest floor. Room doors can be unlocked with a key/tools or shot open; guests occupy the suites. Break the east corridor window to reach the external fire escape. The guarded platform beside the wall connects the alternating stair flights at each end. Police can climb the same route and breach the room you entered; ground units can cover the exit below.

## Checks and publishing

```sh
node tests/acceptance.cjs
node scripts/build.cjs
```

The acceptance harness executes the shipped game functions. It checks footprint overlaps and entrances, physical windows/floors, stair pursuit/descent, room breaches, bridge support, swimming depth and oxygen, opaque-water line of sight, rescue ladders, vehicle ratios, sprinting, incident deduplication, arrest recovery, officer reboarding/redeployment, bridge pursuit and barriers, restrained PIT contact, map audio suspension, helicopters/spikes, directional diving/surfacing and water jumps, bridge reinforcement spawns, glancing impacts and fire escape timing, all seven main mission stage handlers, unlocked/replayable operations, open-ground and circular-sprint gunfights, physical driver extraction, theft success/cancellation, real officer ejection, fair spawn visibility/travel time, far bridge approach staging, and accelerating fire warnings. It does not replace browser/rendering or human playtesting.

Pushing `main` runs these checks, builds `dist/index.html` from the canonical `Kestrel Bay.html`, and publishes through GitHub Pages. Do not edit the generated `dist` copy.

The renderer caches full-height exterior walls, recessed windows and roofs, then culls offscreen, rear-facing and fully hidden façades. Nearby floors load their furnished interiors; visible towers retain real window geometry across their height. Traffic recovery and navigation are lightweight sandbox AI; they are not a full driving or tactical simulation. Campaign progress is saved to browser local storage. Local-file and hosted saves belong to different browser origins.
