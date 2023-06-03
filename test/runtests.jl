using MakieDraw
using Test
using Makie
using GeometryBasics
using GeoJSON
using GeoInterface

figure = Figure()
axis = Axis(figure[1:10, 1:10])

paint_canvas = PaintCanvas(falses(100, 100); figure, axis)

paint_canvas.active[] = false

line_canvas = GeometryCanvas{LineString}(; figure, axis)

line_canvas.active[] = false

point_canvas = GeometryCanvas{Point}(; figure, axis)

point_canvas.active[] = false

poly_canvas = GeometryCanvas{Polygon}(; figure, axis)

layers = Dict(
    :paint=>paint_canvas.active, 
    :point=>point_canvas.active, 
    :line=>line_canvas.active,
    :poly=>poly_canvas.active,
)

MakieDraw.CanvasSelect(figure[2, 1], axis; layers)

# Write the polygons to JSON
# Have to convert here because GeometryBasics `isgeometry` has a bug, see PR #193
polygons = GeoInterface.convert.(Ref(GeoInterface), poly_canvas.geoms[])
mp = GeoInterface.MultiPolygon(polygons)
GeoJSON.write("multipolygon.json", mp)


# Reload and edit again on a new figure
polygons = collect(GeoInterface.getgeom(GeoJSON.read(read("multipolygon.json"))))

figure = Figure()
axis = Axis(figure[1, 1])
poly_canvas = GeometryCanvas(polygons; figure, axis)

