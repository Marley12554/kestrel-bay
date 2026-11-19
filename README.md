# Kestrel Bay

A standalone WebGL island-city sandbox. First person on foot, third person in vehicles. No install, server, external assets, or package dependencies.

**[Play](https://Marley12554.github.io/kestrel-bay/)** · **[Source](https://github.com/Marley12554/kestrel-bay)**

## Play locally

Open `Kestrel Bay.html` in a desktop browser with WebGL enabled. Click **Enter the Bay**, then click the game to capture the mouse. Press Escape to release it. Operations are accepted explicitly from the map; the next job is never automatically assigned.

| Control | Action |
| --- | --- |
| WASD / mouse | Move / look; steer in a car |
| Shift | Sprint; vehicle boost |
| Space | Jump; vehicle boost |
| C / Q | Crouch / dive when swimming |
| E | Open doors, use objects, enter or leave a vehicle |
| 1 / H | Unarmed / holster |
| 2 / 3 / 4 / 5 | Pistol / shotgun / carbine / tools |
| Mouse wheel | Cycle owned equipment |
| Left click / J / R | Fire / alternate fire key / reload |
| X | Handbrake |
| M | Map and operations; click the map to set a waypoint |
| Helicopter | WASD movement; E/Q altitude; mouse heading; F board/exit |
| Plane | W/S throttle; A/D rudder; mouse heading/pitch; automatic gear; F board/exit |

Touch controls are also available. Shotguns, carbines, supplies, bypass tools, repairs, and vehicle deliveries can be bought at suppliers. The striped Interceptor is also the starter car.

## This pass

- Meridian occupies its own island, joined to the mainland by two elevated bridges. The organized center connects to a diagonal theater district, Civic Circle, public courts, mixed-height shore neighborhoods, the eastern wooded promenade, and working docks. The city and mainland use over 250 generated buildings with direct street or courtyard access.
- Building rooms stay in the building's footprint and world coordinates. Floors, elevator shafts and moving platforms, door locks, transparent breakable windows, occupied guest rooms, and exterior fire stairs are physical. All generated buildings are enterable; tall buildings have usable floors rather than off-map rooms.
- Hotels, apartments, offices, cafés, restaurants, shops, garages, warehouses, civic buildings, and prison spaces use different modular layouts. These are procedural low-poly interiors, not individually hand-authored rooms.
- Normal car profiles restore the pre-nerf values. The striped Interceptor has better steering and an unboosted top speed 1.20× the cruiser. Its boost improves acceleration without raising that speed ceiling. Sprint is 135 world units/s, up from 100.
- Drivers and pedestrians report crimes. Reports from the same incident share severity; killing a witness cannot retract an already received report. Cameras, police sight and a dispatched helicopter can maintain contact. A sustained crime-free period outside observation is still necessary to lose heat.
- Pursuing cruisers can leave roads, reverse out of congestion, deploy officers, and pick their officers back up. Officers traverse exterior stairs and breach room doors. One ground unit can cover an upper-floor escape while others pursue. Faster escapes at higher heat can bring a spotter helicopter and physical spike strips.
- The hotbar starts unarmed. Drawing a gun near a patrol officer draws attention. Shotguns and carbines are purchasable and have distinct models, ammunition, fire rates, and reloads.
- Arrest progress recovers while in a vehicle. Evidence interactions are gated to the relevant accepted operation and their markers clear after completion. Seven main operation stage paths remain playable.

## Hotel route to try

Set a map waypoint to **Mariner Grand** in Meridian. Open its north entrance, walk into reception, and use the elevator in the southwest part of the lobby. Choose a guest floor. Room doors can be unlocked with a key/tools or shot open; guests occupy the suites. Break the east corridor window to reach the external fire escape. The narrow platform beside the wall connects the alternating stair flights at each end. Police can climb the same route and breach the room you entered; ground units can cover the exit below.

## Checks and publishing

```sh
node tests/acceptance.cjs
node scripts/build.cjs
```

The acceptance harness executes the shipped game functions. It checks footprint overlaps and entrances, physical windows/floors, stair pursuit/descent, room breaches, bridge support, vehicle ratios, sprinting, incident deduplication, arrest recovery, officer reboarding, helicopters/spikes, and all seven main mission stage handlers. It does not replace browser/rendering or human playtesting.

Pushing `main` runs these checks, builds `dist/index.html` from the canonical `Kestrel Bay.html`, and publishes through GitHub Pages. Do not edit the generated `dist` copy.

The renderer uses simplified distant building shells and loads nearby floor details. Traffic recovery and navigation are lightweight sandbox AI; they are not a full driving or tactical simulation. Campaign progress is saved to browser local storage. Local-file and hosted saves belong to different browser origins.
