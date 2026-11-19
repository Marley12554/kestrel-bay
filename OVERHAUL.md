# Kestrel Bay implementation notes

The current pass supersedes the original single-island layout and off-map interior plan.

## World contract

Four world units represent one foot. Eye height is 22.5 units; a floor is 44 units (11 feet). Meridian is a separate island east of the original mainland. Founders Suspension Bridge and Harbor Viaduct provide elevated connections. Blackwater remains a separate prison island; Fort Halcyon retains its mainland peninsula and runway.

Road nodes and links are generated before parcels. The central city deliberately retains a coherent grid, interrupted by diagonal streets, omitted links/T junctions, Civic Circle, public squares, and the coastal ring. Low- and mid-rise shore frontage forms a transition to the organized center. Reservations protect landmark sites before other parcels are populated. Every footprint and front entrance is checked against other buildings and nearby road access.

## Physical architecture

There are no interior coordinate offsets. `player.z`, a building's footprint, floor plans, collision walls, door and window state, elevator platform, and external stairs all use the same world coordinates. Interiors do not change player x/y when opening the entrance. Elevator travel physically boards and moves the platform inside its shaft; a platform on another floor is called to the player first.

Floor plans are generated lazily for each building/floor and cached. Nearby floors have actual wall openings, glass, doors and furnishings. Distant/upper/lower shells reduce geometry cost. All generated buildings have entrance geometry; all tower floors can be selected from their lift. Smaller buildings use exterior stairs for upper access. Nearby stair geometry is drawn with nearby floor details; distant stair treads and rail posts are omitted while their physical collision remains indexed. Bridge decks are rendered once at their actual elevation, with solid ramp undersides and edge barriers. The exterior fire stair has physical guardrails and alternates between two separate parallel flights; narrow wall-side platforms connect each floor's window to the end landings.

Hotel suites contain occupants, beds, desks, wardrobes, lounges and divided bathrooms. Residential lobbies, hotel reception, civic displays, offices, suppliers, restaurants, garages and prison cells use separate modular arrangements. Individual rooms remain procedural, with repeated furniture modules.

## Movement and equipment

Sprint increased from 100 to 135 units/s; regular movement is 64 units/s. Stamina recovery, crouching, jumping, swimming, limited breath, and third-person chase cameras remain. Car max-speed/acceleration profiles restore sedan 780/780, taxi 730/700, sport 1200/1100, muscle 1000/930, van 650/580 and cruiser 1380/1265. The striped Interceptor uses 1656/1518 and improved steering. Its boost does not lift its top-speed limit. Cruisers are 15% faster than the fastest ordinary car (the unstriped sport), and the Interceptor retains a 20% speed advantage over cruisers. These are simulation values, not mph; the HUD converts using the world scale.

The five-slot hotbar holds unarmed, pistol, shotgun, carbine and tools. Only owned equipment can be selected. The player starts unarmed with a pistol available. Space jumps on foot and boosts in a vehicle; click/J fires the selected gun. Different firearms use different magazines, damage, spread, rates and reloads.

## Pursuit contract

Crimes feed a shared incident record. Witnesses can corroborate an incident without each adding its full severity; greater injury can upgrade that incident by the unreported difference. Further separate crimes still escalate heat. Tracking comes from cameras, human sight, received reports, and an airborne spotter at higher heat. Sight is height-aware and floor slabs occlude it. Windows admit sight but block bodies/bullets until broken. Searches retain the existing sustained crime-free/unobserved escape requirement.

Cruisers use the road graph for long routes and steering/collision for a clear off-road approach. Congested mobile vehicles reverse and rejoin a route. Officers are linked to their cruiser and seat, leave it physically and return to it when a fleeing driver gets away. Reboarded officers are passengers and can dismount again; they do not fill the on-foot response cap or obstruct traffic. Moving pursuit matches target velocity and predicts beyond segment joins, so straight bridge joins do not create repeated braking. Moderate-speed PIT attempts require actual contact and are disabled on bridges. Interior pursuit uses physical stair routes and door breaches; a second mobile cruiser can cover the lower fire exit. Simultaneous police fire is limited and officers commit to an aim point before firing. Spike strips are visible physical hazards placed by an arrived blocking unit. No predictive ROADBLOCK waypoint or advance deployment toast is exposed.

## Missions and regression scope

Keep the seven explicitly accepted campaign operations, optional recovery/race/aircraft contracts, prison rescue, military facilities, tanks, boats and aircraft. The courier for the later accounts operation starts in Meridian. Evidence is available only for the relevant operation and is marked consumed when that operation completes; a later operation explicitly resets its own evidence availability. Existing saves migrate equipment defaults.

Acceptance checks exercise mission stage handlers and shared mechanics, not a complete real-time playthrough of every possible mission approach. Browser QA checks actual WebGL startup, controls, door entry, lift menu/travel, hotbar and map layout. Performance and emergent multi-agent behavior still need user playtesting on target hardware.

## Repository

`Kestrel Bay.html` is the canonical standalone game. `scripts/build.cjs` emits the Pages entry point into ignored `dist/`. `tests/acceptance.cjs` executes source-based regression checks without external dependencies. `.github/workflows/pages.yml` tests, builds and deploys `main` to GitHub Pages.

Opening the map suspends the Web Audio context; closing it resumes the audio timeline. Background tabs also suspend audio. Fixed physics substeps cover up to half a second of elapsed frame time so slow rendering does not produce the previous severe simulation slowdown. Surface support queries use the local spatial index rather than scanning all fire escapes.

## Volumetric water and damage follow-up

The water surface is consistently at world z=-9. A surface swimmer's feet are at z=-24, with the eye three units above the water; looking down/up while moving changes real depth. Releasing input holds underwater depth. Space rises from depth and becomes a ballistic exit jump near the surface. Oxygen is based on submersion, and drowning follows depletion. The seabed slopes away from the shore; piers/causeways are physical slabs, and the land render has lake/basin cutouts. Water is opaque on both sides, with short blue underwater visibility. Shore/bridge observers can reacquire an exposed head, while rays through the surface are occluded.

Bridge response uses persistent approach patrols and staged interceptions; reinforcements are no longer created on an exposed span. Local response counts allow replacement units to approach without counting a distant fleet as a nearby response. Officers use dry bridge/shore positions to follow a swimmer. Physical rescue ladders lead from the sea to the elevated bridge sidewalk; an E interaction animates the ascent and the step over the guardrail.

Collision damage uses normal impact speed and a contact cooldown, with capped damage per hit. Tangential scrapes preserve forward motion. Real damage produces smoke below 55% engine condition and fire below 18%. A burning/wrecked vehicle gives ten seconds to exit before exploding. Emergency exits remain available at speed while burning or flooded. Explosions use three-dimensional distance. Flooded cars extinguish and sink; boats float relative to the same water level.

`tests/water-impacts.js` exercises real dive depth, neutral depth hold, surfacing, water jumps onto a pier, drowning, exposed-head reacquisition, coastal tracking, ladder ascent, bridge dispatch, high-speed glancing contact, damage-free ramp entry, visible engine condition, fire escape time, and vertical blast separation. Browser checks cover the actual shader, input-driven swimming, the opaque water ceiling, warning effects and bailing out.

## Coordinated response and vehicle entry follow-up

Every casebook operation is available immediately, including completed operations for replay; completion records, equipment and preparation remain separate. An unowned vehicle requires three timed green-zone hits with shrinking windows. A miss, Escape, damage, moving away or opening the map cancels the attempt. Occupied vehicles visibly eject their actual driver/crew before boarding. During the door struggle dispatch cannot independently order that same crew out, while other officers remain free to intervene. Starter, purchased and previously owned vehicles bypass the timing game.

Persistent patrols at both ends of each bridge exist before a chase starts. Dispatch distinguishes a tail, forward interception, side containment and reserve. The bridge holding point is on the final approach before the junction splits; high-heat units lay a real spike strip there. New cruisers are created only on land, outside whole-car visibility (including the actual chase camera and recent views) and beyond eight seconds of possible closing time. Helicopters approach from ahead and fly fast enough to track the striped car. Ground-junction rails leave turning space.

Officers detect exposed suspects at 300 feet, draw weapons for violent threats and engage out to about 263 feet. Two simultaneous shooters use observed movement and bounded turn estimates, short bursts and reloads; the rest close or flank. One-star unarmed suspects are approached for arrest. Officers navigate around car bodies and can reach a safe door on a stationary or creeping car, begin a visible grab, then pull the driver out. Accelerating interrupts the grab. Boarded or stunned/ejected officers cannot invisibly arrest the player.

A burning vehicle's paint pulses red with increasing frequency while smoke, flames and a visible countdown retain the ten-second exit window. H honks while driving using sustained dual tones and harmonics; H still holsters on foot.

`tests/encounters.js` runs exposed one-star approaches, circular and straight sprint gunfights, actual wall cover, driver extraction and interruption, theft success/cancellation, real officer ejection, spawn fairness, warning pulses, and complete update-loop theft and bridge-staging scenarios. Browser captures confirmed the unlocked casebook, timing overlay and officer-ejection stage. The browser encounter run stopped at its retry limit; a dispatch/ejection conflict found there was subsequently reproduced and fixed in deterministic integration tests. Remaining rendered encounter/audio QA is not claimed complete.

## Fire-escape landing repair

The shared stair generator previously ran flights between landing centers, burying the last treads inside the upper landing. The player's leading body corners could then hit the platform underside just before the feet reached it. This reproduced on both city and town buildings. Flights now meet the platform edges, use evenly spaced treads with the top tread flush to the landing, and retain continuous flight rails. No jump or movement-speed workaround is used.

The regression suite walks three clear lateral approaches to every generated upper landing (2,856 flights), and complete representative city/town routes in both directions with landing turns and no jump input. WebGL keyboard checks also cover both alternating directions, upper floors and a complete switchback ascent/descent.

## Driving feedback, traffic, occupied-car response and visibility

The free starter is now an owned, low-speed compact (about 48 mph in the unboosted driving model), parked in a paved bay beside the starting café, outside the road and entrance route. Existing nearby starters are reused. Ordinary cars and striped Interceptors retain their previous speed profiles.

Engine audio uses a quiet low-frequency combustion note and second harmonic, with bounded pitch and gear drops. It no longer increases oscillator pitch directly with unlimited road speed. Traffic horns use a short local two-tone sound, one horn per direct obstruction and a seven-second global ambient spacing; queued followers remain quiet. Manual H honking remains available.

Spikes trigger a one-time hiss/impact, an explicit temporary puncture banner and persistent tire HUD status. Tire rubber disappears, gray rims remain, and moving rims throw sparks. Repeated contact does not replay the alert. Height checks prevent strips on another deck from puncturing a car. Repairs restore tires and cabin glazing.

Civilian recovery no longer reverses direction or abandons a route. A passing maneuver checks road length, approaching traffic, pedestrians and collision clearance, then waits for a safe right-lane merge gap after clearing the obstruction or queue. Unsafe passing means waiting in the original lane. Police retain their separate congestion recovery.

A stationary occupied car gets close containment positions, including bridge-appropriate longitudinal positions. Cruisers remain mounted until near the car, then deploy. One officer approaches the door and maintains the extraction attempt while others cover; breaking a car window with repeated police fire exposes its occupant to further window hits. This preserves a brief protection advantage without making remaining inside an idle car a safe haven.

Full-height exterior meshes share the exact physical window/door profiles with local interior geometry. Recessed window openings, wall returns and roofs are cached in GPU buffers; frustum tests, front-face selection and conservative occlusion by opaque buildings reduce visible work. Complete furnished floors remain local, with live opening/broken-window state invalidating only that building's cached exterior. There is no distant flat tower substitute or five-floor band of exterior detail.

The isolated 1,366 × 850 browser benchmark measured median renderer times of about 6.4/6.9/1.2 ms in three views before the change and 2.4/2.1/0.8 ms after it. Dynamic geometry fell from 78,342/97,776/8,106 vertices to 22,980/24,438/366; cached façade geometry is drawn separately. A brute-force full-interior estimate was 10.2 million vertices (272 MB at the existing vertex format). These are isolated renderer measurements; total game performance also includes simulation and varies by hardware.

`tests/driving-city.js` checks the starter bay and speed, engine pitch, safe overtaking/merging, opposing-lane waiting, horn limits, puncture feedback, close multi-cruiser deployment/extraction, cabin exposure, full-height window meshes and conservative occlusion. Browser checks cover the rendered skyline, starter bay, tire alert/rims, coordinated extraction and actual offline Web Audio output. The tested engine's dominant frequency at sports-car speed was 63 Hz; simultaneous ambient horn requests produced one two-tone horn.

## Dock response and dispatch lifetime repair

A five-star idle report at Drydock Six reproduced a zero-ground-response failure. Fair spawning required new cruisers to start at least about 12,000 map units away, while world cleanup deleted nonpersistent police outside 11,000 units. The dock also lay outside every seeded patrol's old 6,000-unit activation radius. Incoming units could therefore disappear while nearby districts never sent their parked crews. Cargo stacks additionally overlapped a Drydock Road lane and trapped the marina approach.

Active dispatched cruisers now survive their road journey. Inbound units count toward the response target, avoiding repeated replacement waves. Available patrols are selected by connected road travel distance and get routes immediately; nearby patrols retain response priority even with distant units already assigned. They can spot a wanted suspect while on patrol. Bridge approach reservations survive the normal dispatch delay. Ground teams search around an on-foot/last-known report instead of parking far ahead of a stale heading. Cargo stacks remain in the freight yard with both Drydock Road lanes physically clear.

The no-visible-spawn rule, minimum encounter travel time, global response cap, sight/last-known-position tracking and sustained unobserved escape conditions remain in effect. No units are teleported to the player.

`tests/dock-dispatch.js` covers five-star idle reports at the drydock on foot/in a car and at the marina edge, actual dismount/contact, backup-only arrival, the exact far-spawn cleanup boundary, stable inbound quotas, remote/local patrol activation, bridge reservation during dispatch and lane clearance. Browser scenarios using the complete update loop reached contact at roughly 11–21 simulated seconds with existing patrols, and about 36 seconds with freshly dispatched backups only. Those timings are observed test runs, not fixed response timers.


## Night, prison and marine pass

Full world cycle: 600 gameplay seconds, split into 300 daylight and 300 night seconds. The prison operation advances to 22:00 at the marina briefing and temporarily holds the astronomical clock; gameplay, guards and puzzles continue. Completion, failure and casebook abandonment release that hold. The map continues to suspend both simulation and audio.

Night rendering uses a reusable 1024×512 shadow atlas for up to eight nearby spotlights. Headlights, boat bow lights, flashlights, street/interior lamps and sweeping prison searchlights illuminate geometry and water. Walls cast shadows; glass passes light. Perception uses the same cone geometry and physical occlusion. Distant sources retain cheap visible bulbs; full-height building geometry is preserved. Headless Chrome samples at 1366×850 measured approximately 7.3/7.5 ms for a city day/night frame, 3.2/3.4 ms at the dock, and 8.8/10.3 ms inside an upper floor. These are isolated render measurements on the test renderer, not a guarantee of whole-game frame rates on every device. A rendered-pixel test verified that an intervening wall reduced spotlight illumination behind it.

Restricted population generation applies to Blackwater and Fort Halcyon, including civilian road routing and indoor occupant roles. Prison rooms contain prisoners rather than random residents; administration remains staff space. Authored perimeter and cellblock patrols use accessible routes, while an authorized service van circulates internally. Access gates default to closed, independently of power. Guards and troops share predictive, fast-projectile burst/reload combat and limited simultaneous shooters.

Seven marine launches exist persistently: five coastal police boats and two prison launches. Swept-hull water navigation avoids land, piers and bridge supports; graph destinations are normalized to navigable water. The nearest response group uses distinct projected interception positions, with the remaining launches retaining patrol roles. Crews maintain sightings, contain shore approaches, fire under the shared combat rules and visibly board stopped boats after a cancellable warning. Boat crews never remotely arrest swimmers.

The prison mission now distinguishes briefing, boat boarding, dock landing, surveillance sabotage, gate access, cell release, escort boarding and mainland escape. Arrival stages advance automatically. The surveillance cabinet is physically outside the secured gate and its waypoint matches its model. Circuit panels use different solvable wire routes with alarm branches, persistent cancelled progress, live guards and damage interruption. Power disables surveillance/searchlights, without granting access cards or opening doors. Custody cards and bypass tools provide separate access paths. Checkpoints restore height, access and sabotage state, and retries restore the night hold. Completion/failure/abandonment restore normal cycling; mission replay resets its own cell controls.

Regular sport top speed: 1080, striped Interceptor: 1490.4 (both 10% lower). Cruiser top speed stays 1380 and its acceleration stays 1265; the striped car now has an 8% configured advantage. Engine gain is 30% higher with pitch unchanged. The driving camera's reach and elevation are reduced 25%, preserving collision retraction.

HUD cash is beneath the minimap; wanted stars and response status are upper right. Thick, labelled HP/stamina/vehicle-health/nitro/oxygen meters include numbers. Stamina drain highlights the bar, exhaustion pulses and displays the 20% sprint-recovery threshold, with a short breath cue.

`tests/night-security.js` and `tests/marine.js` cover clock halves/locking, restricted populations, routing puzzles, independent power/gates/cards, retry restoration, night visibility/occlusion, predictive guard combat, patrol clearance, swept water routes, physical response, cancellable boarding and remote-arrest prevention. The existing regression suites remain in the publishing workflow. Browser QA covers real WebGL day/night scenes, desktop/mobile HUD, actual circuit button interaction, rendered shadow occlusion and mission-stage UI/update integration. Staged transport fixtures isolate arrival checks; this is not a claim of manually sailing and sneaking through every possible approach.


Verification for this pass: all source acceptance suites passed, including real pier-side E entry, full-update escort boarding/arrival completion, physically locked cells, inmate movement through the released door, and per-responder floor selection. Browser checks passed WebGL startup, day/night rendering, mobile HUD, actual circuit button interaction and real wall-shadow occlusion (the sampled ground changed from RGB 58/77/108 to 28/37/52 behind the wall). Observed headless Chrome medians for selected scenes were approximately 3–9 ms in daylight and 3–10 ms at night; these are rendering samples, not a target-hardware frame-rate guarantee.

The extended browser mission-stage run reached the retry limit. It exercised casebook acceptance, boat theft/entry, dock arrival and the three distinct circuit panels, but did not pass its final escort-boarding assertion. Earlier attempts had harness variable and persisted-checkpoint contamination; the boarding fixture also removed the player from a vehicle without changing that vehicle's occupied state. Full-update deterministic boarding/arrival checks use the actual E entry path and pass. No complete unassisted real-time prison playthrough is claimed.


## Periodic freeze repair

The marine controller previously ran an entire water-graph search synchronously whenever a route expired or failed. A blocked coastal route could search most of the sea graph and hold the main thread. Quiet military/prison guards also continued pathfinding far outside the player's area.

Water routing is now a resumable generator serviced by a round-robin work queue, using a heap frontier and cached hull-clear edges. The scheduler targets 1.5 ms and at most 40 yields per update across all launches. It checks the time between chunks, so a single chunk or JIT compilation may overrun that target. Existing routes remain usable while a replacement is planned; job requests are deduplicated and urgent response cancels outdated patrol work. Quiet/offscreen guard simulation is culled beyond 2,500 world units (625 feet), while nearby patrol and combat behavior resumes immediately. Shared night-illumination samples invalidate when lights or the player move, avoiding repeated identical raycasts.

All existing acceptance suites remain, with `tests/frame-budget.js` added for live-loop synchronous-search prevention, shared work limits, scheduling fairness, stale-job replacement, remote/near guard behavior and visibility-cache correctness. Native-browser profiling covered 90 simulated seconds across daytime town, nighttime city and a five-star response. Simulation median / p99 / maximum were approximately 2.6 / 4.1 / 13.7 ms, 2.4 / 3.5 / 4.0 ms, and 1.9 / 4.9 / 29.2 ms; no simulated update exceeded 100 ms. These samples validate the observed scenarios, not all hardware or every emergent chase. The first browser profiling setup overused synchronous software-GPU readbacks; the successful run measured update timings and sampled render submissions separately in a clean Chrome profile.

## Building circulation and fire-escape collision repair

The clearance audit reproduced furniture in 594 sampled elevator aprons. Floor plans now declare protected cabin, apron, hall-access, entrance and escape-window spaces before furnishings are generated. Furniture colliders and associated decorative geometry both honor those spaces. Interior partitions split around reserved passages; elevator core walls remain structural. Bathroom openings are generated explicitly instead of deleting an assumed number of previously emitted vertices. North-entry counters/reception desks face into the room rather than blocking the approach. Public frames are widened consistently in cached and detailed geometry, and public entry interaction takes priority over a nearby prop.

The old window-side walkway left almost no clearance between a body, the wall and its rail. Its usable width, both stair flights and the landing turns are now wider. Tread render tops and quantized support heights share the same elevations. Support samples the character's foot corners, closes the façade-floor seam and resolves small falling contacts (up to 4.5 inches) onto a platform. Falling movement cannot freely enter a landing's side. Broken ordinary low window sills have grounded step assistance and actual leading-foot support; intact glass continues to block passage. Officer routes use the same escape dimensions.

Acceptance checks cover all 254 public entrances at three approach offsets, elevator exit and re-entry on 802 representative floor plans, actual elevator arrival, broken escape and ordinary-window crossing, landing-lip recontact, 2,810 generated flights, and sprint turns at 20/30/60 FPS. The complete 13-suite regression run passed. Native Chrome checks passed actual E entry, elevator floor selection/travel and walk-out, actual gunfire opening an escape window, crossing the façade onto the ledge, turning along it and resolving falling contact onto a landing. Captures confirmed clear interior circulation and visible escape structure. The first browser harness attempt tried to serialize a circular building object; returning a primitive fixed that test-only error.
