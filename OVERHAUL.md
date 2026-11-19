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
