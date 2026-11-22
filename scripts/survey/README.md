# 1350 Broadway survey pilot

The pilot covers the 25-story Herald Square Building and its four-story south wing. The corner at West 35th has three wide window bays on its short face, a green band between studio floors, and a red bank fascia wrapping both corners. The office tower steps back independently of the low wing. The Broadway and Sixth Avenue vestibules have push-through revolving doors. West 36th has a separate recessed freight entrance. [Owner's exterior photographs](https://www.esrtreit.com/properties/office/1350-broadway1/) · [Lobby access plan, printed page 12](https://www.esrtreit.com/wp-content/uploads/1350-RTO-Final-2.16.pdf)

## Geographic control

The game uses a fixed origin near Bryant Park. One game unit is one metre. X increases east and Z increases south. The projected coordinates, axis conventions and vertical origin apply to every survey cell. Godot Y = NAVD88 elevation in metres minus 10. The borough-wide source archive uses 2014 aerial geometry. The elevation raster uses 2017 bare-earth LiDAR at one-foot source spacing. The build converts US survey feet, samples pixel centres in the correct State Plane projection, and triangulates a globally aligned one-metre grid. [Frame definition](frame.json) · [NYC 3-D model](https://www.nyc.gov/assets/planning/download/pdf/data-maps/open-data/nyc-3d-model-metadata.pdf) · [NYC elevation metadata](https://elevation.its.ny.gov/arcgis/rest/services/Dem_Indexes/FeatureServer/0)

The old survey has two building IDs on lot 1008110031. NYC's newer footprint has one building, BIN 1080606 and DOITT ID 354757. The source building footprints, joined at their common party wall, agree with its published State Plane perimeter at stored precision. Their maximum roof agrees at 379.21 feet NAVD88. A direct conversion of the public longitude/latitude export gave a roughly three-foot shift here. Requesting the same record from NYC's service in its native EPSG:2263 coordinates resolved it. These are comparisons of related maps. NYC estimates its photogrammetric footprint accuracy at about two feet. [NYC footprint metadata](https://github.com/CityOfNewYork/nyc-geo-metadata/blob/main/Metadata/Metadata_BuildingFootprints.md) · [Source URLs, control ring and per-face decisions](herald-reference.json)

The measured core is 367 feet square. A temporary 262-foot collar joins its outside edges to the old flat preview. The four faces and their sidewalks are in the core. Surveyed pavement retains its hard curb where the road and sidewalk meet. Baking subtracts the curb at LiDAR sample points before adding it on the actual sidewalk geometry. The camera, walking controller and vehicle can sample the same triangulated surface. The two lobby floors have level interiors and sloped entrance aprons. Buildings beyond the pilot use the earlier map until their own terrain pass.

## Rebuild

The packaged game includes the baked resources. Rebuilding needs the Midtown CityGML extract in `dist/midtown-source`, NYC DEM tile `be_NYC_025.tif`, and Python with NumPy, Shapely 2.1+, mapbox-earcut, rasterio and pyproj. Run from the repository root with Godot 4.7.1 on the command path. [CityGML source](https://www.asg.ed.tum.de/gis/projekte/new-york-city-3d/) · [Elevation tile](https://gisdata.ny.gov/elevation/DEM/NYC_TopoBathymetric2017/be_NYC_025.tif)

```sh
python3 scripts/survey/grade.py /path/to/be_NYC_025.tif
python3 scripts/survey/check-grade.py /path/to/be_NYC_025.tif
python3 scripts/survey/build-herald.py
python3 scripts/mesh-midtown.py
python3 scripts/midtown-street-collision.py
godot --headless --path preview --script ../scripts/pack-midtown.gd
godot --headless --path preview --script ../scripts/pack-midtown-walls.gd
godot --headless --path preview --import
godot --headless --path preview --script ../tests/herald-block.gd
godot --headless --path preview --script ../tests/midtown-block.gd
```

## What the pilot established

- Eight off-grid street and entrance-area checkpoints compared the finished surface to the original DEM. At the first bake the mean absolute difference was 0.6 inches and the largest was 1.2 inches. This measures interpolation error against the raster. Field survey uncertainty is additional.
- An adjacent cell was baked independently to the east and kept out of the playable map. Its 113 shared elevation vertices and 449 pavement samples agreed with the pilot. For a larger covered region, move the temporary blend to its outer boundary. Keep the current datum and grid alignment across internal edges.
- The measured shell and roof setbacks come from CityGML. The facade recipe records the four photographed elevations, chamfer, distinct shop runs, freight access and office window groupings. The source photographs give proportions. Exact sash dimensions, recess depths, storefront lighting and the vestibule finishes are estimates. The visible retail represents the reference material, which spans different dates. The reconstructed entrances stop at the vestibules.
- A separate photograph from Sixth and 35th checks the tower setbacks rising behind the low wing, three south-facing studio bays and the bank sign turning the corner. Signs above the retail level, street furniture and individual room furnishings have incomplete coverage. [Comparison photograph](https://www.noahre.com/hubfs/Building%20Photos/1350%20Broadway.jpg)
- The first source collection, implementation and review took roughly half an hour. With sources cached, a repeat terrain bake took about two seconds and the facade bake about four seconds on the project Mac. Researching addresses, reconciling IDs and reviewing all visible sides still require time per property. The existing Midtown extract also has fixed geographic bounds. A block with several adjoining owners, shared walls and changing rooflines is the next distinct production test.


The long tower elevations have recessed central window strips and continuous piers. The setbacks cut off each pier at its own roofline. The historic Wendy’s channel letters use the lettering from the [period artwork](https://logos-download.com/brands/wendys). The bank fascia uses [Santander’s white lockup](https://www.santander.com/content/dam/santander-com/images/logo/santander-logo-negative.svg). The Reserve storefront uses the [wordmark](https://www.starbucksreserve.com/icons/wordmark.svg) and [star-R](https://www.starbucksreserve.com/media_17ef589560738227b6d42bcd9bccf4b751fa6db48.svg) from Starbucks Reserve.

The plaza footprint with BIN 1089436 has a one-foot measured height and a 49-foot modeled wall. Its location and NYC restaurant record correspond to the [Wafels & Dinges kiosk at 35th Street](https://34thstreet.org/shop-eat/wafels-dinges-herald-sq). The replacement uses a level counter with a chamfered perimeter, service windows and a shallow metal roof. Fixture dimensions are photo estimates. The importer reports additional height conflicts for inspection.
