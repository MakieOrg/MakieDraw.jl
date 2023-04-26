using MakieDraw
using Test
using GLMakie
using GeometryBasics
using GeoJSON
using GeoInterface
using TileProviders
using Tyler
using Extents
provider = Google(:satelite)
tyler = Tyler.Map(Extent(Y=(-27.0, 0.025), X=(0.04, 38.0)); provider)
display(fig)
fig = tyler.figure;
axis = tyler.axis;

# fig = Figure()
# ax = Axis(fig[1, 1])

line_canvas = GeometryCanvas{LineString}(; fig, axis)

Tables.istable(tyler)

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
