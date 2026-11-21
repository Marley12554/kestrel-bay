# Midtown street preview

Start on foot at Fifth Avenue and West 34th Street. Walk with WASD at 4.2 mph. Hold Shift to sprint at 8.5 mph, or tap Sprint on touchscreens to toggle it. Press **F** to leave your body and fly, and **F** again to return. In freecam, use the slider for 2–2,400 mph, E to climb and Q to descend. Drag to look or double-click for captured mouse look. Escape releases the pointer. Press E by the teal sedan to drive, then E while stopped to get out. H hides or restores the HUD. Touch controls provide the same actions.

The Fifth Avenue entrance, West 34th Street observatory entrance and holiday storefronts are modeled for this block. The [Fifth Avenue lobby reference](https://www.twotwelve.com/project/empire-state-building) and [visitor entrance directions](https://www.esbnyc.com/hours-directions) informed the layout.

Geometry comes from the [Technical University of Munich NYC CityGML project](https://www.asg.ed.tum.de/gis/projekte/new-york-city-3d/) and the underlying NYC Open Data building and street surveys. Building shapes reflect the 2014 survey. The source places streets on a flat plane. Building bases are aligned with that plane while preserving individual building heights. The rendering uses illustrative surface colors.

The committed compressed Godot scene builds without the source ZIPs. To regenerate it, put the citywide archives in `source-assets/NYC-CityGML/`, run `python3 scripts/extract-midtown.py`, then run `python3 scripts/mesh-midtown.py` with numpy and mapbox-earcut installed. Finish with `godot --headless --path preview --script ../scripts/pack-midtown.gd`. Use the Web export preset in the preview project for deployment. Regenerate the walking and driving collision resource with `python3 scripts/midtown-street-collision.py` and `godot --headless --path preview --script ../scripts/pack-midtown-walls.gd`.

## Native winter block

The browser build opens the winter block using Compatibility. The macOS build starts in the evening on Fifth Avenue and uses Metal with Forward+ lighting. Approach the sedan and press E to drive. Hold the left mouse button and drag to look. F toggles freecam on foot. H hides the control hint. The downloadable art credits are in [winter/CREDITS.txt](winter/CREDITS.txt).

With the Godot 4.7.1 macOS release template installed, run `godot --headless --path preview --editor --import --quit`, then `godot --headless --path preview --export-release "Mac Native" "../dist/native/Fifth Avenue.app"` after creating the destination directory.
