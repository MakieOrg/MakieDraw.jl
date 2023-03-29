# MakieDraw

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://rafaqz.github.io/MakieDraw.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://rafaqz.github.io/MakieDraw.jl/dev/)
[![Build Status](https://github.com/rafaqz/MakieDraw.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/rafaqz/MakieDraw.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/rafaqz/MakieDraw.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/rafaqz/MakieDraw.jl)


Plot an interactive canvas of GeometryBaseics `Point`, `LineString` or `Polygon`, or an ms-paint style canvas for any numerical or color `Array`. These can be overlayed and activated/deactivated to have multiple drawing task on the same `Axis`.

[makie_draw_life.webm](https://user-images.githubusercontent.com/2534009/228633357-52798d12-36dc-4bb7-a1d4-fdb620aa5ca6.webm)


_Drawing into a DynamicGrids.jl simulation_

# Example use cases
- `GeometryCanvas` can be used to manually crreate GeoInterface.jl compatible FeatureCollections (and even add metadata columns for each geometry), which can be done over a heatmap or other spatial plot. A `GeometryCanvas` can be written directly to disk with GeoJSON.jl or Shapefile.jl.
- `PaintCanvas` can be used to manually edit matrices of any kind that Makie can plot. You could make `Bool` mask layers over maps or other images, edit categorical images, or just draw some retro pictures on a `Matrix{RGB}`. 
- MakieDraw could also be used for live interaction, such as using `PaintCanvas` as a mask or aux layer in DynamicGrids.jl simulations.

[makie_draws-2023-03-29_17.48.57.webm](https://user-images.githubusercontent.com/2534009/228595860-ae996719-c4a3-4479-b4da-f65183da867a.webm)

_Drawing with the example below_

```julia
using MakieDraw
using GLMakie
using GeometryBasics
using Colors

fig = Figure()
axis = Axis(fig[1:10, 1])

# Make a Point canvas
point_canvas = GeometryCanvas{Point2}(; fig, axis)
point_canvas.active[] = false

# Make a LineString canvas
line_canvas = GeometryCanvas{LineString}(; fig, axis)
line_canvas.active[] = false

# Make a Polygon canvas
poly_canvas = GeometryCanvas{Polygon}(; fig, axis)
poly_canvas.active[] = false

# Make a heatmap paint canvas
data = zeros(RGB, 150, 80)
paint_canvas = MakieDraw.PaintCanvas(data; fill_right=RGB(1.0, 0.0, 0.0), fig, axis)

# Use red on right click
paint_canvas.fill_right[] = RGB(1.0, 0.0, 0.0)

# Create a canvas select dropdown
layers = Dict(
  :point=>point_canvas.active, 
  :line=>line_canvas.active, 
  :poly=>poly_canvas.active, 
  :paint=>paint_canvas.active,
)
MakieDraw.CanvasSelect(fig[11, 1], axis; layers)
```
