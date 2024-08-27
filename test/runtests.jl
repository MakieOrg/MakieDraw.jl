using MakieDraw
using Test
using Makie
using GeometryBasics
using GeoJSON
using GeoInterface

figure = Figure()
axis = Axis(figure[1, 1])

paint_canvas = PaintCanvas(falses(100, 100); figure, axis)

polys = [Polygon([Point(10.0, 50.0), Point(50.0, 70.0), Point(70.0, 10.0), Point(10.0, 50.0)])]
poly_canvas = GeometryCanvas(polys; figure, axis);

layers = Dict(
    :paint=>paint_canvas, # Passing any AbstractCanvas works
    :poly=>poly_canvas.active, # an Observable{Bool} also works
)

# Add a Canvas selector
cs = MakieDraw.CanvasSelect(figure[2, 1]; layers)

# We can push to it
line_canvas = GeometryCanvas{LineString}(; figure, axis)
push!(cs, :line=>line_canvas)

# line_canvas it should be active now

# And also set values
point_canvas = GeometryCanvas{Point}(; figure, axis)
cs[:point] = point_canvas 

# Write the polygons to JSON
# Have to convert here because GeometryBasics `isgeometry` has a bug, see PR #193
polygons = GeoInterface.convert.(Ref(GeoInterface), poly_canvas.geoms[])
mp = GeoInterface.MultiPolygon(polygons)
GeoJSON.write("multipolygon.json", mp)


# Reload and edit again on a new figure
geojson_polys = collect(GeoInterface.getgeom(GeoJSON.read(read("multipolygon.json"))))

figure = Figure()
axis = Axis(figure[1, 1])
polys = [Polygon([Point(1.0, 2.0), Point(2.0, 3.0), Point(3.0, 1.0), Point(1.0, 2.0)])]
poly!(polys)
poly_canvas = GeometryCanvas(geojson_polys; figure, axis);

# TODO: click and keypress testing
# event.keyboard[] = value 
# scene.events.mousebutton[] = ... 
