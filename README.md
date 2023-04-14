# MakieDraw

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://rafaqz.github.io/MakieDraw.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://rafaqz.github.io/MakieDraw.jl/dev/)
[![Build Status](https://github.com/rafaqz/MakieDraw.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/rafaqz/MakieDraw.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/rafaqz/MakieDraw.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/rafaqz/MakieDraw.jl)


Plot an interactive canvas of GeometryBaseics `Point`, `LineString` or `Polygon`, or an ms-paint style canvas for any numerical or color `Array`. These can be overlayed and activated/deactivated to have multiple drawing task on the same `Axis`.

[makie_draw_life.webm](https://user-images.githubusercontent.com/2534009/228633357-52798d12-36dc-4bb7-a1d4-fdb620aa5ca6.webm)


_Drawing into a DynamicGrids.jl game of life simulation_

# Example use cases
- `GeometryCanvas` can be used to manually crreate GeoInterface.jl compatible FeatureCollections (and even add metadata columns for each geometry), which can be done over a heatmap or other spatial plot. A `GeometryCanvas` can be written directly to disk with GeoJSON.jl or Shapefile.jl.
- `GeometryCanvas` can also be used to edit any GeoInterface.jl compatible geometries and feature collections.
- `PaintCanvas` can be used to manually edit matrices of any kind that Makie can plot. You could make `Bool` mask layers over maps or other images, edit categorical images, or just draw some retro pictures on a `Matrix{RGB}`. 
- MakieDraw could also be used for live interaction, such as using `PaintCanvas` as a mask or aux layer in DynamicGrids.jl simulations.

[makie_draws-2023-03-29_17.48.57.webm](https://user-images.githubusercontent.com/2534009/228595860-ae996719-c4a3-4479-b4da-f65183da867a.webm)

Or try this example over Tyler.jl tiles:

```julia
using MakieDraw
using GLMakie
using GeoJSON
using GeometryBasics
using GeoInterface
using TileProviders
using Tyler
using Extents
provider = Google(:satelite)
tyler = Tyler.Map(Extent(Y=(-27.0, 0.025), X=(0.04, 38.0)); provider)
fig = tyler.figure;
axis = tyler.axis;

line_canvas = GeometryCanvas{LineString}(; fig, axis)

line_canvas.active[] = true
point_canvas = GeometryCanvas{Point}(; fig, axis)

point_canvas.active[] = false
poly_canvas = GeometryCanvas{Polygon}(; fig, axis)

layers = Dict(
    :point=>point_canvas.active, 
    :line=>line_canvas.active,
    :poly=>poly_canvas.active,
)

MakieDraw.CanvasSelect(fig[2, 1], axis; layers)

# Write the polygons to JSON
# Have to convert here because GeometryBasics `isgeometry` has a bug, see PR #193
polygons = GeoInterface.convert.(Ref(GeoInterface), poly_canvas.geoms[])
mp = GeoInterface.MultiPolygon(polygons)
GeoJSON.write("multipolygon.json", mp)

# Reload and edit again
polygons = collect(GeoInterface.getgeom(GeoJSON.read(read("multipolygon.json"))))
tyler = Tyler.Map(Extent(Y=(-27.0, 0.025), X=(0.04, 38.0)); provider)
fig = tyler.figure;
axis = tyler.axis;
poly_canvas = GeometryCanvas(polygons; fig, axis)
```

`GeometryCanvas` keys:

Left click to add, grab or drag points, right click to remove them.

Shift + left click starts new lines and polygons.

`PaintCanvas` keys:

Left click draws with `fill_left`, right click draws with `fill_right`.
