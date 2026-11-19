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
