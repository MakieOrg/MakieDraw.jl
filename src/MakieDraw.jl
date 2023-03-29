module MakieDraw

using GeometryBasics, Makie

const GI = GeometryBasics.GeoInterface

export GeometryCanvas, CanvasSelect

abstract type AbstractCanvas end

include("geometry_canvas.jl")
include("paint_canvas.jl")
include("canvas_select.jl")
include("utils.jl")

end

