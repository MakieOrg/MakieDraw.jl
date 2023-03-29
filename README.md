# MakieDraw

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://rafaqz.github.io/MakieDraw.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://rafaqz.github.io/MakieDraw.jl/dev/)
[![Build Status](https://github.com/rafaqz/MakieDraw.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/rafaqz/MakieDraw.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/rafaqz/MakieDraw.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/rafaqz/MakieDraw.jl)


Plot an interactive canvas of GeometryBaseics `Point`, `LineString` or `Polygon`, or an ms-paint style canvas for any numerical or color `Array`. These can be overlayed and activated/deactivated to have multiple drawing task on the same `Axis`.

[makie_draws-2023-03-29_17.48.57.webm](https://user-images.githubusercontent.com/2534009/228595860-ae996719-c4a3-4479-b4da-f65183da867a.webm)


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

# Use red on left click
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
