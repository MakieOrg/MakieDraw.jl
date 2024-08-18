var documenterSearchIndex = {"docs":
[{"location":"","page":"Home","title":"Home","text":"CurrentModule = MakieDraw","category":"page"},{"location":"#MakieDraw","page":"Home","title":"MakieDraw","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Documentation for MakieDraw.","category":"page"},{"location":"","page":"Home","title":"Home","text":"","category":"page"},{"location":"","page":"Home","title":"Home","text":"Modules = [MakieDraw]","category":"page"},{"location":"#MakieDraw.CanvasSelect","page":"Home","title":"MakieDraw.CanvasSelect","text":"CanvasSelect <: AbstractCanvasSelect\n\nA menu widget for selecting active canvases.\n\nIt will deactivate all non-selected canvases, and select the active one.\n\nArguments\n\nfigure::Union{Figure,GridPosition} a Figure or GridPosition.\nax::Axis: the Axis the canvases are on.\n\nKeywords\n\nlayers: Dict{Symbol,Orbservable{bool}\n\nExample\n\nlayers = Dict(\n    :paint=>paint_canvas.active, \n    :point=>point_canvas.active, \n    :line=>line_canvas.active,\n    :poly=>poly_canvas.active,\n)\n\nMakieDraw.CanvasSelect(figure[2, 1], axis; layers)\n\n\n\n\n\n","category":"type"},{"location":"#MakieDraw.GeometryCanvas","page":"Home","title":"MakieDraw.GeometryCanvas","text":"GeometryCanvas{T<:GeometryBasics.Geometry} <: AbstractCanvas\n\nGeometryCanvas{T}(; kw...)\n\nA canvas for drawing GeometryBasics.jl geometries onto a Makie.jl Axis.\n\nT must be Point, LineString or Polygon.\n\nMouse and Key commands\n\nLeft click select point, or add point with property 1 if click_property is set.\nRick click select point, or add point with property 2 if click_property is set.\nMiddle click select point, or add point with property 3 if click_property is set.\nAlt+click: delete points, dragging will click is held will continue deleting.\nShift+click: start new polygons and linstrings on Polygon and LineString canvas. Has no effect for Point.\nDelete: delete selected points.\nShift+Delete: delete selected linestring/polygon.\n\nKeywords\n\ndragging: an Observable{Bool}(false) to track mouse dragging.\nactive: an Observable{Bool}(true) to set if the canvas is active.\naccuracy_scale: control how accurate selection needs to be. 1.0 by default.\nname: A Symbol: name for the canvas. Will appear in a CanvasSelect.\npropertynames: names for feaure properties to create.\nproperties: an existin table of properties.\nclick_property: which property is set with left and right click, shold be a Bool.\nfigure: a figure to plot on.\naxis: an axis to plot on.\ncurrent_point: an observable to track the currently focused point index.\nscatter_kw: keywords to pass to scatter.\nlines_kw: keywords to pass to lines.\npoly_kw: keywords to pass to poly.\ncurrent_point_kw: keywords for the current point scatter.\nshow_current_point: whether to show the current point differently to the other.\ntext_input: wether to add text input boxes for property input.\n\n\n\n\n\n","category":"type"},{"location":"#MakieDraw.PaintCanvas","page":"Home","title":"MakieDraw.PaintCanvas","text":"PaintCanvas <: AbstractCanvas\n\nPaintCanvas(; kw...)\nPaintCanvas(f, data; kw...)\n\nA canvas for painting into a Matrix Real numbers or colors.\n\nArguments\n\ndata: an AbstractMatrix that will plot with Makie.image!, or your function f\nf: a function, like image! or heatmap!, that will plot f(axis, dimsions..., data) onto axis.\n\nKeywords\n\ndimension: the dimesion ticks of data. axes(data) by default.\ndrawing: an Observable{Bool}(false) to track if drawing is occuring.\ndrawbutton: the currently clicked mouse button while drawing, e.g. Mouse.left.\nactive: an Observable{Bool}(true) to set if the canvas is active.\nname: A Symbol: name for the canvas. Will appear in a CanvasSelect.\nfigure: a figure to plot on.\naxis: an axis to plot on.\nfill_left: Observable value for left click drawing.\nfill_right: Observable value for right click drawing.\nfill_middle: Observable value for middle click drawing.\n\nMouse and Key commands\n\nLeft click/drag: draw with value of fill_left\nRight click/drag: draw with value of fill_right\nMiddle click/drag: draw with value of fill_middle\n\n\n\n\n\n","category":"type"},{"location":"#MakieDraw.arrow_key_navigation-Tuple{Any, Any}","page":"Home","title":"MakieDraw.arrow_key_navigation","text":"arrow_key_navigation(fig, axis)\n\nAllow moving the axis with keyboard arrow keys.\n\n\n\n\n\n","category":"method"}]
}
