module MakieDraw

using GeometryBasics, GeoInterface, Makie, Tables

const GI = GeoInterface

export GeometryCanvas, PaintCanvas, CanvasSelect

abstract type AbstractCanvas end

include("geometry_canvas.jl")
include("paint_canvas.jl")
include("canvas_select.jl")
include("utils.jl")

end

