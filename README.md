# Kestrel Bay

A single-player Godot open world set in a compressed New York harbor. Start in Old Harbor, Brooklyn with a parked compact. Cross the river into Manhattan, follow the Queens waterfront, or leave Pier 04 for Blackwater. All eleven operations are available from the map. Free roam, completed jobs and the three endings of *Public Record* are available independently.

**[Play Kestrel Bay](https://marley12554.github.io/kestrel-bay/)** · **[Play the original HTML edition](https://marley12554.github.io/kestrel-bay/classic/)**

## Controls

| Input | Action |
| --- | --- |
| WASD, mouse | Walk and look. Click the game view to capture the mouse. |
| Shift, Space, C | Sprint, jump or rise in water, crouch. Swim in the direction you look. |
| E, F | Interact or enter/exit a road vehicle or boat. F boards or exits aircraft. |
| Vehicle entry | At a parked car, press E at the driver’s door. At an occupied car, hold E or the touch Use button while you stay alongside. |
| Surrender | Holster and press E near an officer when the surrender prompt appears. |
| WASD in a car | Accelerate, reverse and steer. Hold Shift, Space or X to drift. H sounds the horn. |
| Q in a car | Lean from the driver's window. Select the pistol to fire. |
| 1–5, left click, R | Select equipment, use it and reload. |
| M, Escape | Map and operations, close a menu or release the mouse. Opening the map pauses sound and time. |
| Helicopter | WASD to move, E/Q to climb or descend. |
| Plane | W/S throttle, A/D rudder and mouse to steer or pitch. Landing gear deploys automatically. |

On a touch screen, use the left stick to move and drag the right side to look. Tap Sprint once to toggle it. Vehicles have separate brake and drift controls. A browser with WebGL 2 is required. Saved progress stays in the browser on the origin where you play. The web build imports supported money, completed operations, equipment and earned prison dock progress from Classic.

## Run the Godot edition locally

Open `godot-prototype/project.godot` in Godot 4.7.1 and press Play. For a web release install the matching Web export template and run these commands from the repository root. Set `GODOT_BIN` if your Godot executable is elsewhere.

```sh
node scripts/godot.cjs test
node scripts/build.cjs
node scripts/godot.cjs serve
```

Open [the local game](http://127.0.0.1:8065/). The single-threaded export and Classic are assembled under `dist/site`. GitHub Actions checks both editions, builds the Web export and publishes that directory to Pages.

With that server running, `node tests/godot-web.cjs` exercises the exported game in Chrome. It checks touch input, pointer capture, the casebook, and a five-star nighttime crossing into a downtown hotel. It also reports frame intervals during the drive. The browser check uses Node 22 or later. Set `CHROME_BIN` for a different Chromium installation, or `KB_SHOTS` to keep screenshots.

## Working on the city

The city layout and the navigation atlas share one source, `scripts/design-city.py`. After changing it, run `python3 scripts/design-city.py` and `node scripts/godot.cjs bake`. The committed scene contains batched exterior geometry. Doors, elevators, nearby furnished floors, police, traffic and missions run in `godot-prototype/bay/`. The original waterfront scene and its regression checks are also part of the project.

<details>
<summary>Original HTML edition, controls and implementation notes</summary>

### Classic controls

Open `Kestrel Bay.html` in a desktop browser with WebGL enabled. Click **Enter the Bay**, then click the game to capture the mouse. Press Escape to release it. All operations are unlocked and accepted explicitly from the map; completed jobs can be replayed. The next job is never automatically assigned.

| Control | Action |
| --- | --- |
| WASD / mouse | Move / look; steer in a car |
| Shift | Hold to sprint on desktop |
| Space | Jump on foot; hold the handbrake while driving |
| C | Crouch |
| Water | WASD swims in the direction you look; look down/up and press W to dive/surface; Space rises and jumps out |
| E | Open doors, use objects, begin vehicle entry or leave a vehicle |
| Vehicle theft | Click / Space / E in the green zone, three rounds; Escape cancels. Misses, damage or moving away cancel immediately |
| 1 / H | Unarmed / holster on foot; H honks while driving |
| 2 / 3 / 4 / 5 | Pistol / shotgun / carbine / tools |
| Mouse wheel | Cycle owned equipment |
| Left click / J / R | Fire / alternate fire key / reload |
| X | Alternate handbrake key; steer while holding to drift |
| Hold Q in a ground car | Lean out the left window; mouse aims, click/J fires the pistol; R reloads; release Q retracts |
| M | Map and operations; click the map to set a waypoint |
| Helicopter | WASD movement; E/Q altitude; mouse heading; F board/exit |
| Plane | W/S throttle; A/D rudder; mouse heading/pitch; automatic gear; F board/exit |

Touch controls are also available. Shotguns, carbines, supplies, bypass tools, repairs, and vehicle deliveries can be bought at suppliers. The free starter is a slow compact in an off-street café bay. Striped Interceptors must be found or bought.

## This pass

- Meridian occupies its own island, joined to the mainland by two elevated bridges. The organized center connects to a diagonal theater district, Civic Circle, public courts, mixed-height shore neighborhoods, the eastern wooded promenade, and working docks. The city and mainland use over 250 generated buildings with direct street or courtyard access.
- Building rooms stay in the building's footprint and world coordinates. Floors, elevator shafts and moving platforms, door locks, transparent breakable windows, occupied guest rooms, and exterior fire stairs are physical. All generated buildings are enterable; tall buildings have usable floors rather than off-map rooms.
- Hotels, apartments, offices, cafés, restaurants, shops, garages, warehouses, civic buildings, and prison spaces use different modular layouts. These are procedural low-poly interiors, not individually hand-authored rooms.
- Normal car profiles use the pre-nerf values, with regular sports cars and striped Interceptors now reduced 10%. Police top speed and acceleration remain unchanged. The striped Interceptor has better steering and an 8% top-speed advantage over a cruiser. Sprint is 135 world units/s, up from 100.
- Drivers and pedestrians report crimes. Reports from the same incident share severity; killing a witness cannot retract an already received report. Cameras, police sight and a dispatched helicopter can maintain contact. A sustained crime-free period outside observation is still necessary to lose heat.
- Dispatch keeps inbound cruisers alive throughout their road journey and mobilizes available patrols beyond the immediate neighborhood. Nearby patrols still react when distant units are assigned. Both dock approach lanes remain clear of cargo stacks.
- Pursuing cruisers can leave roads, reverse out of congestion, deploy officers, and pick their officers back up. Officers traverse exterior stairs and breach room doors. One ground unit can cover an upper-floor escape while others pursue. Faster escapes at higher heat can bring a spotter helicopter and physical spike strips.
- Water uses actual body and camera depth, an opaque surface, a seabed, blue distance fog, and oxygen while submerged. Letting go holds depth; Q no longer fakes a dive. Space provides a water exit jump. Marina piers and causeways have physical slabs, and bridge rescue ladders provide a route back up to the sidewalk.
- Vehicle collision damage uses velocity into the obstacle, so a glancing scrape does not count as a full-speed crash. Engine damage produces smoke; a critical engine/wreck burns visibly with a ten-second exit window. Burning or flooded vehicles permit an emergency exit. Explosions account for height, and flooded cars sink rather than standing on the water.
- Persistent patrols occupy the bridge approaches before a chase starts. Dispatch assigns a tail, an intercept, containment and reserve positions. A unit holds the final bridge approach before the road splits, with physical spike strips at high heat. New reinforcements enter from land with at least eight seconds of possible closing time; whole-car camera visibility, free-look and recent views are checked. Helicopters arrive outside the camera view at three stars, including ordinary-car chases, and report only targets inside their unoccluded search cone. Surfacing exposes the head again; officers track swimmers from the bridge/shore and cannot see through the water surface.
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
node scripts/build.cjs --classic
```

The acceptance harness executes the shipped game functions. It checks footprint overlaps and entrances, physical windows/floors, stair pursuit/descent, room breaches, bridge support, swimming depth and oxygen, opaque-water line of sight, rescue ladders, vehicle ratios, sprinting, incident deduplication, arrest recovery, officer reboarding/redeployment, bridge pursuit and barriers, restrained PIT contact, map audio suspension, helicopters/spikes, directional diving/surfacing and water jumps, bridge reinforcement spawns, glancing impacts and fire escape timing, all seven main mission stage handlers, exact 300-second day/night halves, guarded-zone population restrictions, independent prison access and power, circuit routing/checkpoint recovery, water-route hull clearance, marine pursuit/boarding, unlocked/replayable operations, open-ground and circular-sprint gunfights, physical driver extraction, theft success/cancellation, real officer ejection, fair spawn visibility/travel time, far bridge approach staging, and accelerating fire warnings. It does not replace browser/rendering or human playtesting.

Classic is copied from `Kestrel Bay.html` to `dist/site/classic/index.html` during a Pages build.

The renderer caches full-height exterior walls, recessed windows and roofs, then culls offscreen, rear-facing and fully hidden façades. Nearby floors load their furnished interiors; visible towers retain real window geometry across their height. Traffic recovery and navigation are lightweight sandbox AI; they are not a full driving or tactical simulation. Campaign progress is saved to browser local storage. Local-file and hosted saves belong to different browser origins.

### Night operations and marine response

The full day/night cycle is ten minutes of gameplay: five minutes of daylight and five minutes of night. Opening the map pauses the simulation and audio. Car/boat headlights, officer/guard flashlights, streetlights, interior fittings, and prison searchlights illuminate real surfaces. Up to eight nearby lights cast shadows through a shared atlas; detection uses physical line of sight and illumination, and underwater targets remain concealed by the opaque water surface.

Blackwater and Fort Halcyon exclude ambient civilian traffic and pedestrians. Blackwater has controlled prisoner rooms, staff posts, interior and perimeter guard patrols, and an authorized service van. Both facilities have secured access gates. Guards and soldiers retain their stronger predictive bursts and reloads; ordinary police use the slower, lower-damage combat described below.

Five persistent police launches cover the coasts; two dedicated security launches patrol Blackwater. Responders use navigable water routes, projected interception positions and shore containment. A crew can visibly board a stopped boat and force its driver overboard after a warning period; accelerating interrupts boarding. Crews cannot arrest swimmers remotely from their boats.

The Island Run starts with a safe marina briefing, fades to 10 PM and holds night until completion, failure or abandonment. Dock landing completes by physically arriving on the pier on foot. Surveillance sabotage, service-gate access and cell release are separate actions. Rotate circuit tiles to join IN to OUT while avoiding the alarm terminal, then test the circuit. Each panel has a different route; Escape cancels, progress persists and the world keeps running. Custody cards are separate from office visitor cards. Power cuts cameras and searchlights, without opening doors or granting cards. Escort boarding and mainland arrival complete automatically. Existing delivery and meeting arrival stages also advance without an extra E press.

Cash sits beneath the minimap, wanted stars and response status have their own upper-right panel, and the lower-left meters explicitly label HP, stamina, vehicle health, handbrake state and oxygen. Sprint exhaustion pulses and names the 20% recovery threshold. The driving camera is 25% closer, with its collision handling preserved, and engine audio is modestly louder without changing its low-frequency character.

### Frame-stall fix

Marine route searches now run as resumable background jobs with a shared 40-step / 1.5 ms target work budget per simulation update, a heap frontier, and cached water-edge checks. Individual steps can overrun the time target slightly; a full world search never runs in the live update. Boats keep existing routes while planning, and urgent pursuit replaces obsolete patrol work. Distant guards stop pathfinding until the player is within their activation range; nearby guards retain their normal combat. Responders share the player's illumination calculation when the player and lights have not changed.

`tests/frame-budget.js` covers deferred/fair routing, work caps, duplicate and stale job handling, urgent marine activation, guard activation and visibility-cache invalidation. A headless Chrome profile sampled 30 simulated seconds each in the starting town, nighttime city and a five-star response. The measured worst simulation updates were approximately 14, 4 and 29 ms respectively, with no updates over 100 ms in those runs. Rendering was sampled separately without forcing repeated software-GPU readbacks; these figures do not guarantee frame rates on other hardware.

### Building access and fire-escape repair

Elevator cabins, their exit aprons and routes into the hall are reserved before furnishings are placed. Furniture and its decorative props respect those spaces, along with public entry routes and fire-escape window approaches. Service counters face away from north-side entrances. Public door frames are wider, and nearby entry doors take interaction priority over interior props.

Fire escapes have wider window-side walks, flights and turn platforms. Visible treads and their collision heights agree; support checks use the character's feet rather than only the center point, and small falling contacts settle onto the platform. Broken low window sills step over naturally, while façade-floor support connects continuously to the escape platform. Police stair paths share the same dimensions.

`tests/accessibility.js` audits offset entry at all 254 buildings and elevator exit/re-entry on 802 representative lobby, upper, records and top floors. It also checks window crossing, ledge turns, falling landing contact and actual elevator arrival. The stair audit covers 2,810 generated flights, with additional sprint/turn checks at 20, 30 and 60 FPS. Browser checks exercise actual entry input, the elevator menu/trip, shooting open the exit window and walking onto the fire escape.

### Police, window shooting and lighting balance

Cruisers now steer, accelerate, brake and collide through the same ground-vehicle physics as the player. Existing vehicle speed profiles are unchanged. Following units continue through projected pursuit targets instead of braking toward them as stopping points. On open ground, the director assigns a tail, a contact unit and separate flanks. Nearby units cross passable lawns; an open road is not required. Road intercepts use reachable arrival estimates and hold their planned points for six seconds; passing the point releases a unit back into pursuit. Bridges retain a following/support unit and a held exit team, with no bridge PITs. Five mobile responders fit inside the existing six-unit response cap. Cruisers steer around vehicles when a clear corridor is available, and civilian drivers yield even to a cruiser that has slowed behind them.

Ordinary officers use two-round bursts, longer aim/recovery pauses and lower damage. Exposure still makes their aim more effective, and at most two responders fire simultaneously. Leaving a vehicle requires a brief aim reacquisition, rate-limited so repeated seat hopping cannot renew it. This is reaction time rather than invulnerability; existing bullets still hit. Guard and military combat remains stronger. Stopped-car containment, breached cabin windows and physical driver extraction remain active.

At three stars, an unarmed helicopter can respond to any vehicle or a suspect on foot. Its visible searchlight cone, physical occlusion and opaque water determine contact; leaving that cone returns it to searching the last known position. Daylight uses a wider visual cone. Police boats chase, intercept, contain shorelines and board slow/stopped boats, without routine gunfire from aboard their launches.

Hold Q in a ground car and select the pistol (2) to lean through the left window. Mouse movement aims within the left-side firing arc, click/J fires, and R reloads. WASD still drives. Releasing Q retracts the body and restores the normal chase camera; aircraft retain their Q controls. The muzzle is physically outside the window, ammunition is shared with the on-foot pistol, and the exposed torso can be shot.

Moving beams update after vehicle and NPC physics on every tick. Stable source identities, shadow-slot hysteresis and fades replace eight-nearest-light swapping. Player headlights and the copter beam receive priority. Street fixtures remain visible with cached, obstacle-clipped ground illumination throughout the rendered district, independently of the eight dynamic shadow slots. Static street pools do not require per-frame light searches or shadow rendering.

`tests/police-balance.js` checks open-ground assignments/movement, PIT eligibility around other cruisers, ordinary-officer reaction time and sustained damage, seat-hopping reacquisition limits, real window shooting/exposure, copter cone occlusion, ordinary-car air dispatch, physical contact against a mildly weaving compact, unarmed marine pursuit, fresh moving headlights, stable shadow selection and cached street illumination. Acceptance randomness is seeded so traffic and burst timing regressions are reproducible. The bridge fixture starts an already pursuing cruiser at a matching physical speed rather than requiring instant acceleration from rest. Browser checks exercised actual Q/fire input and night rendering without WebGL errors. A 90-second simulation profile across day, city night and five-star response recorded no simulation updates above 100 ms; the largest sampled update was about 44 ms on the test machine. This does not replace human playtesting or guarantee a frame rate on other hardware.

### Window aim and headlight corrections

Window aiming uses a wider camera orbit, seated hips and a connected leaning torso through the driver's open window. Only the pistol slot displays a pistol; unarmed peeking keeps it holstered. The crosshair traces the visible surface, then the physical barrel aims at that point. Camera sampling is shared with the shot frame, close-range spread stays within the reticle, and a muzzle-side obstruction changes the marker to the actual blocking point.

Vehicle headlights and glowing headlamp fixtures operate only at night, including immediate shutdown at dawn. Light positions no longer draw separate floating emissive boxes. Shadowed beams accumulate before a bounded exposure calculation, so several cruisers cannot multiply the ground into white.

The fifteenth acceptance suite, `tests/window-aim.js`, checks actual projectile hits across nine near/far/angled targets, vehicle hit volumes, barrel/reticle agreement, body/window placement, the unarmed model, camera framing, muzzle cover and day/dawn/dusk/night gating. Browser checks cover real Q/weapon/fire/reload input. A rendered-pixel test measured unlit ground at RGB 27/37/51, one headlight at 62/67/71 and seven overlapping lights at 120/124/121; adding a wall restored the unlit value. A ten-second window-aim simulation/raycast sample had no updates above 100 ms (largest sampled update about 1.4 ms on the test machine).

### Handbrake drifting and mobile sprint

Nitro and its fuel meter are removed. Space or X holds the car's handbrake; S/down still brakes and reverses. The HUD shows whether the handbrake is held or the car is drifting, without a fuel/cooldown bar. Handbrake turns retain sideways momentum, then progressively recover grip on release. Rear-wheel paths leave paired, continuous rubber tracks on pavement and bridge decks. Harder slip makes them darker and wider; they fade and are capped to bound rendering work. Stationary cars, lawns and bare wheel rims do not paint rubber tracks.

On mobile, tap SPRINT to toggle it on, then move with the joystick; tap it again to return to jogging. Stamina limits still apply. The button becomes a held HAND BRAKE in cars, with a separate held BRAKE pedal that stops without automatically reversing. The on-foot brake button is now JUMP. Entering/exiting vehicles and opening the map clear latched/held input to avoid carrying sprint or a pedal into the next context. Helicopter controls read UP/DOWN and plane controls THR +/THR −.

`tests/drift-mobile.js` adds actual toggle/run/jog movement, independent pedal fingers, pause/context resets, jumping, drift/regrip, variable track appearance, fading, bridge height, terrain gating and aircraft labels. Native mobile browser checks verified running/jogging speeds, HUD/context labels, held pedals and visible drift tracks. The browser harness stopped afterward on a redundant touch-release cleanup command; no additional browser attempts were made.

</details>
