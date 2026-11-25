# Fifth Avenue for Unreal

The native desktop project opens at the Fifth Avenue sidewalk near East 33rd Street. Press **J** to visit 1350 Broadway at Herald Square and press it again to return to your previous position and view. The additional production block lies immediately north, between Broadway, Sixth Avenue, West 36th and West 37th Streets. The surrounding Midtown survey supplies the existing city context.

WASD moves or drives. Space jumps, Shift sprints or applies the handbrake, E enters or exits the nearby sedan, operates a swing door or orders coffee at the Reserve counter. Push into a revolving leaf to turn it. The arrow keys toggle the turn signals. T switches between day and night, F toggles flight, and Escape opens the graphics and mouse sensitivity sliders. A fresh user profile starts on Low and subsequent launches load the saved choice.

## Build and measure on Mac

Ordinary play uses a 60 FPS cap. The benchmark runs uncapped. Launch the packaged executable with `-AvenueRoadTest` to exercise the Herald Square round trip and drive across the painted intersection. It records storefront, moon and road screenshots in the game’s Saved directory.

The native assets and level are checked in. From the repository root, run `scripts/unreal/package-mac.sh` with Unreal 5.8 installed under `/Users/Shared/Epic Games/UE_5.8`, or set `UE_ROOT`. The script builds matching editor and game modules before cooking and produces `dist/unreal-mac/Mac/FifthAvenue.app`. A compatible Xcode and Metal shader compiler are required. Unreal's desktop game target also contains the shared Windows gameplay source.

Launch the packaged executable with `-AvenueBench -windowed -ResX=1512 -ResY=982 -ForceRes -NoVSync`. The benchmark allows six seconds for startup, measures the same twenty-second street camera route twice, and exits. The second pass adds eight collision traces and short tracer effects per burst, plus four pooled local flashes. Results include average, 95th, 99th and worst wall-clock frame times, and the number exceeding 16.67 ms. This is a synthetic effects load. It does not measure a playable combat AI or networked match. Add `-AvenueBlockBench` to run the route on the new West 36th Street block, or add `-AvenueDriveBench` to exercise the sedan, including acceleration, braking and steering. The game writes `AvenueBench.csv` in its Saved directory and prints the same measurements in its log. An optional `-AvenueCapture` saves a screenshot before the timing window.

## Survey and asset provenance

The existing city geometry, commercial signs, vehicles, characters, recorded gaits, sound and lunar image come from the Fifth Avenue preview. See the source credits under `preview/winter`, `preview/audio`, and `preview/people`. Unreal uses centimeters. Each Godot point (east, height, south) maps to Unreal (east, south, height) multiplied by 100. The origin, CRS and vertical datum are defined in `scripts/survey/frame.json`.

The adjacent block uses NYC CityGML buildings 1015241–1015244 on tax block 812. The LiDAR production area extends the existing pilot north using the same NYC elevation raster and sidewalk survey. The façades retain the surveyed massing and setbacks. The Greenwich Savings Bank's Broadway portico, West 36th Street engaged columns, street-level openings and attic follow the NYC Landmarks Preservation Commission's [exterior designation](https://s-media.nyc.gov/agencies/lpc/lp/1766.pdf). Office bay dimensions and material finishes on the surrounding parcels are estimates. The low-rise contains Selvedge, an original fabric shop with a recessed shop floor and counters. The bank recreation covers its exterior. The Commission also publishes the [interior designation](https://s-media.nyc.gov/agencies/lpc/lp/1767.pdf).

## Rebuild the source assets

1. Prepare the CityGML cache using the existing `scripts/survey` workflow. Bake the extended grade with `scripts/survey/grade.py DEM.tif --core 301008 64816 301208 65016 --out dist/unreal-staging/grade.json` and run `scripts/unreal/west36.py` in the same Python environment.
2. Set `FIFTH_STAGING` to the absolute `dist/unreal-staging` directory. Run Godot in a window with an active renderer. The dummy headless renderer discards instance poses. Use `--path preview --rendering-method gl_compatibility --script /absolute/path/to/scripts/unreal/export_street.gd` to read the instance transforms and colors. Run `export_people.gd` in the same project, then `python3 scripts/unreal/join_people.py "$FIFTH_STAGING"`. Convert the original Ogg footstep recordings to WAV in that directory, retaining their filenames.
3. Run `python3 scripts/unreal/sky_panorama.py` with NumPy and FFmpeg installed to convert the original street panorama. Compile the FifthAvenueEditor target. With `FIFTH_ROOT` set to the checkout, run the Unreal Python commandlet successively on `import_assets.py`, `materials.py`, `build_level.py` and `validate_level.py`. The checked-in level can be packaged without regenerating these assets.

## Desktop verification scope

The repaired Mac package ran in a 1512 × 982 window on the 14-inch M1 Pro using Low (72% internal resolution). The uncapped samples below cover twenty seconds each. A frame above 16.67 ms misses the 60 FPS target.

| Route | Mean (ms) | 99th percentile (ms) | Worst (ms) | Frames above 16.67 ms |
| --- | ---: | ---: | ---: | ---: |
| Fifth Avenue driving | 8.45 | 10.05 | 85.99 | 9 |
| Fifth Avenue driving with effects | 8.37 | 9.58 | 18.12 | 1 |
| West 36th Street | 8.35 | 9.37 | 23.15 | 2 |
| West 36th Street with effects | 8.41 | 9.47 | 63.16 | 5 |

The car reached 61.5 mph during the driving benchmark. An earlier West 36th effects run recorded a 1.16-second hitch. Its cause is unverified. Real input-to-display latency, fan speed and sustained combat performance have not been measured.

The packaged regression on both Low and Ultra returned the walker to the starting position and view after two J presses, then drove the sedan 280 feet across the painted intersection. The level check traced the terrain under Herald Square at 289 points on a roughly ten-foot grid. Packaged Low captures showed the Reserve interior, colored sculpture and textured moon.

The pilot includes the existing Midtown survey and one additional detailed block. The ordinary fabric shop is fictional. The landmark bank has an exterior recreation. Remaining differences from the Godot desktop preview include traffic-signal behavior and dynamic snow tracks. Windows packaging, Windows hardware performance, and automatic delivery of desktop builds have not been verified.
