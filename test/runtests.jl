using MakieDraw
using Test
using Makie
using GLMakie
# using WGLMakie
using GeometryBasics
using MapTiles

using Tyler
using GLMakie
provider = Providers.Google(:satelite)
tyler = Tyler.Map(Rect2f(-27.0, 38.0, 0.04, 0.025); provider)
fig = tyler.figure
ax = tyler.axis

fig = Figure()
ax = Axis(fig[2:10, 1])

line_canvas = Canvas{LineString}()
draw!(line_canvas, fig, ax)
line_canvas.active[] = false

point_canvas = Canvas{Point}()
draw!(point_canvas, fig, ax)
point_canvas.active[] = false

poly_canvas = Canvas{Polygon}()
draw!(poly_canvas, fig, ax)

layers = Dict(
    :point=>point_canvas.active, 
    :line=>line_canvas.active,
    :poly=>poly_canvas.active,
)

MakieDraw.CanvasSelect(fig[1, 1], ax; layers)

# point_canvas.active[] = false

@testset "MakieDraw.jl" begin
end

using GeoInterface
GeoJSON.GeometryCollection(poly_canvas.geoms[])
GeoJSON.write("azores.json", GeoInterface.convert.(GeoJSON.Polygon, poly_canvas.geoms[]))
