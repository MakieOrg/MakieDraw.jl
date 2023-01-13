# MakieDraw

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://rafaqz.github.io/MakieDraw.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://rafaqz.github.io/MakieDraw.jl/dev/)
[![Build Status](https://github.com/rafaqz/MakieDraw.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/rafaqz/MakieDraw.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/rafaqz/MakieDraw.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/rafaqz/MakieDraw.jl)


Plot an interactive canvas of points, lines or polygons. These can be overlayed
and activated/deactivated to have multiple drawing task on the same `Axis`.


```julia
using MakieDraw
using Test
using GLMakie
using GeometryBasics

fig = Figure()
ax = Axis(fig[1, 1])

point_canvas = Canvas{Point}()
draw!(point_canvas, fig, ax)
line_canvas.active[] = false
point_canvas.geoms[]

point_canvas.active[] = false
line_canvas = Canvas{LineString}()
draw!(line_canvas, fig, ax)

line_canvas.active[] = false
poly_canvas = Canvas{Polygon}()
draw!(poly_canvas, fig, ax)

MakieDraw.CanvasSelect(fig[1, 1], ax)
```
