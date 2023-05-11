"""
    GeometryCanvas{T<:GeometryBasics.Geometry} <: AbstractCanvas

    GeometryCanvas{T}(; kw...)

A canvas for drawing GeometryBasics.jl geometries onto a Makie.jl `Axis`.

`T` must be `Point`, `LineString` or `Polygon`.

# Mouse and Key commands

- Left click select point, or add point with property 1 if `click_property` is set.
- Rick click select point, or add point with property 2 if `click_property` is set.
- Middle click select point, or add point with property 3 if `click_property` is set.
- Alt+click: delete points, dragging will click is held will continue deleting.
- Shift+click: start new polygons and linstrings on `Polygon` and `LineString` canvas. Has no effect for `Point`.
- Delete: delete selected points.
- Shift+Delete: delete selected linestring/polygon.

# Keywords

- `dragging`: an Observable{Bool}(false) to track mouse dragging.
- `active`: an Observable{Bool}(true) to set if the canvas is active.
- `accuracy_scale`: control how accurate selection needs to be. `1.0` by default.
- `name`: A `Symbol`: name for the canvas. Will appear in a [`CanvasSelect`](@ref).
- `propertynames`: names for feaure properties to create.
- `properties`: an existin table of properties.
- `click_property`: which property is set with left and right click, shold be a `Bool`.
- `figure`: a figure to plot on.
- `axis`: an axis to plot on.
- `current_point`: an observable to track the currently focused point index.
- `scatter_kw`: keywords to pass to `scatter`.
- `lines_kw`: keywords to pass to `lines`.
- `poly_kw`: keywords to pass to `poly`.
- `current_point_kw`: keywords for the current point `scatter`. 
- `show_current_point`: whether to show the current point differently to the other.
- `text_input`: wether to add text input boxes for property input.
"""
mutable struct GeometryCanvas{T,G,P,CP,I,Pr,TB,F,A,Co} <: AbstractCanvas
    geoms::G
    points::P
    dragging::Observable{Bool}
    active::Observable{Bool}
    accuracy_scale::Float64
    current_point::CP
    section::I
    name::Symbol
    properties::Pr
    properties_textboxes::TB
    figure::F
    axis::A
    color::Co
    on_mouse_events::Function
end
function GeometryCanvas(obj; propertynames=nothing, properties=nothing, kw...)
    if Tables.istable(typeof(obj))
        properties = if isnothing(properties) && !isnothing(propertynames)
            map(propertynames) do name
                collect(Tables.getcolumn(obj, name))
            end |> NamedTuple{propertynames}
        else
            NamedTuple()
        end
        geoms = Tables.getcolumn(obj, first(GI.geometrycolumns(obj)))
    elseif GI.isfeaturecollection(obj)
        properties = if isnothing(properties) && !isnothing(propertynames)
            map(propertynames) do name
                map(GI.getfeature(obj)) do f
                    p = GI.properties(f)
                    if !isnothing(p) && hasproperty(p, name)
                        String(getproperty(p, name))
                    else
                        ""
                    end
                end
            end |> NamedTuple{propertynames}
        else
            NamedTuple()
        end
        geoms = map(GI.geometry, GI.getfeature(obj))
    else
        geoms = collect(obj)
        properties = isnothing(properties) ? NamedTuple() : properties
        # geoms = filter(geoms) do geom
        #     !isnothing(geom)
        # end
    end
    gb_geoms = GI.convert.(Ref(GeometryBasics), geoms)
    GeometryCanvas(Observable(gb_geoms); properties, kw...)
end
GeometryCanvas(on_mouse_events, obj; kw...) = GeometryCanvas(obj; on_mouse_events, kw...)
function GeometryCanvas(obs::Observable; kw...)
    trait = GI.geomtrait(first(obs[]))
    T = GeometryBasics.geointerface_geomtype(trait)
    GeometryCanvas{T}(obs; kw...)
end
function GeometryCanvas{T}(geoms=Observable(_geomtype(T)[]);
    dragging=Observable{Bool}(false),
    active=Observable{Bool}(true),
    accuracy_scale=1.0,
    name=nameof(T),
    propertynames::Union{NTuple{<:Any,Symbol},Nothing}=nothing,
    properties::Union{NamedTuple,Nothing}=nothing,
    click_property=nothing,
    figure=Figure(),
    axis=Axis(figure[1:10, 1:10]),
    current_point=_current_point_obs(T),
    section=nothing,
    color=nothing,
    scatter_kw=(;),
    lines_kw=(;),
    poly_kw=(;),
    current_point_kw=(;),
    show_current_point=false,
    on_mouse_events=no_consume,
    mouse_property=nothing,
    text_input=true,
    input_layout=GridLayout(figure[11, 1]), 
) where T<:Union{Point,LineString,Polygon,MultiPoint}
    axis.aspect = AxisAspect(1)
    geoms = geoms isa Observable ? geoms : Observable(geoms)

    if T <: Point
        points_obs = geoms
    else
        points_obs = if length(geoms[]) > 0
            Observable(geoms_to_points(geoms[]))
        else
            ps = [[Point(1.0, 1.0)]]
            geoms[] = T.(ps)
            Observable(ps)
        end
        # ps will be a Vector of Vector of Point
        # TODO support exteriors and holes with another layer of nesting?
        # Maybe Alt+click could mean "drawing a hole in this polygon now"
        # And section would be 1 here
        on(points_obs) do ps
            geoms[] = T.(ps)
        end
    end

    properties = if isnothing(properties) && propertynames isa Tuple
        map(propertynames) do _
            Vector{String}(String[" " for _ in geoms[]])
        end |> NamedTuple{propertynames}
    else
        properties
    end

    properties = if properties isa NamedTuple
        map(properties) do p
            p isa Observable ? p : Observable(p)
        end
    else
        nothing
    end

    text_boxes = if isnothing(properties) || !text_input
        nothing
    else
        _make_property_text_inputs(figure, properties, current_point, input_layout)
    end

    canvas = GeometryCanvas{T,map(typeof,(geoms,points_obs,current_point,section,properties,text_boxes,figure,axis,color))...}(
        geoms, points_obs, dragging, active, accuracy_scale, current_point, 
        section, name, properties, text_boxes, figure, axis, color, on_mouse_events
    )

    # Plot everying on `axis`
    draw!(figure, axis, canvas; 
        scatter_kw, lines_kw, poly_kw, current_point_kw, show_current_point
    )
    addtoswitchers!(canvas)
    add_events!(canvas; mouse_property)
    return canvas
end

_current_point_obs(::Type{<:Point}) = Observable(1)
_current_point_obs(::Type) = Observable((1, 1))

_geomtype(T) = T
_geomtype(::Type{<:Point}) = Point2

function _make_property_text_inputs(fig, properties::NamedTuple, current_point::Observable, input_layout)
    i = 0
    map(properties) do props
        i += 1
        tb = Textbox(input_layout[1, i]; stored_string=" ")
        T = eltype(props[])
        on(tb.stored_string) do t
            propsvec = props[]
            n = current_point[][1]
            while length(propsvec) < n
                if <: AbstractString
                    push!(propsvec, " ")
                elseif <: Real
                    push!(propsvec, zero(T))
                end
            end
            propsvec[current_point[][1]] = t
            notify(props)
        end
        on(current_point) do cp
            propsvec = props[]
            n = cp[1]
            while length(propsvec) < n
                if T <: AbstractString
                    push!(propsvec, " ")
                elseif T <: Real
                    push!(propsvec, zero(T))
                else
                    error("Only String and Real properties are supported")
                end
            end
            @assert n <= length(propsvec)

            tb.displayed_string[] = lpad(propsvec[n], 1)
            notify(tb.displayed_string)
        end
    end
end

# Base methods
Base.display(c::GeometryCanvas) = display(c.figure)

# GeoInterface.jl methods
GI.isfeaturecollection(::Type{<:GeometryCanvas}) = true
GI.trait(::GeometryCanvas) = GI.FeatureCollectionTrait()
GI.nfeature(::GI.FeatureCollectionTrait, c::GeometryCanvas) = length(c.geoms[])
function GI.getfeature(::GI.FeatureCollectionTrait, c::GeometryCanvas, i)
    properties = if isnothing(c.properties)
        nothing
    else
        map(p -> p[][i], c.properties)
    end
    return GI.Feature(c.geoms[][i]; properties)
end

# Tables.jl methods
Tables.istable(::Type{<:GeometryCanvas}) = true
Tables.columnaccess(::Type{<:GeometryCanvas}) = true
Tables.columns(x::GeometryCanvas) = x

Tables.columnnames(gc::GeometryCanvas) = (:geometry, Tables.columnnames(gc.properties)...)

function Tables.schema(gc::GeometryCanvas)
    props = gc.properties
    proptypes = map(name -> Tables.gettype(props, name), propnames)
    names = collect(Tables.columnnames(gc))
    types = [eltype(gc.geometry), proptypes...]
    return Tables.Schema(names, types)
end

@inline function Tables.getcolumn(gc::GeometryCanvas, i::Int)
    if i == 1
        gc.geoms[]
    elseif 0 < i <= (length(properties) + 1)
        gc.properties[i - 1][]
    else
        throw(ArgumentError("There is no table column $i"))
    end
end
# Retrieve a column by name
@inline function Tables.getcolumn(gc::GeometryCanvas, key::Symbol)
    if key == :geometry
        gc.geoms[]
    elseif key in propertynames(gc.properties)
        gc.properties[key][]
    end
end
@inline function Tables.getcolumn(t::GeometryCanvas, ::Type{T}, i::Int, key::Symbol) where T
    Tables.getcolumn(t, key)
end

# Ploting 
function draw!(fig, ax::Axis, c::GeometryCanvas{<:Point};
    scatter_kw=(;), lines_kw=(;), poly_kw=(;), current_point_kw=(;),
    show_current_point=false,
)
    draw_points!(fig, ax, c; scatter_kw)
    if show_current_point
        draw_current_point!(fig, ax, c; current_point_kw) 
    end
end
function draw!(fig, ax::Axis, c::GeometryCanvas{<:LineString}; 
    scatter_kw=(;), lines_kw=(;), poly_kw=(;), current_point_kw=(;),
    show_current_point=false,
)
    l = if isnothing(c.color)
        lines!(ax, c.geoms; lines_kw...)
    else
        lines!(ax, c.geoms; color=c.color, lines_kw...)
    end
    translate!(l, 0, 0, 98)
    # Show line end points 
    end_points = lift(c.points) do points
        map(points) do ps
            if length(ps) > 1
                [first(ps), last(ps)]
            elseif length(ps) > 0
                [first(ps)]
            else
                Point2[]
            end
        end |> Iterators.flatten |> collect
    end
    e = scatter!(ax, end_points; color=:black, scatter_kw...)
    translate!(e, 0, 0, 99)
    draw_points!(fig, ax, c; scatter_kw)
    if show_current_point
        draw_current_point!(fig, ax, c; current_point_kw) 
    end
end
function draw!(fig, ax::Axis, c::GeometryCanvas{<:Polygon};
    scatter_kw=(;), lines_kw=(;), poly_kw=(;), current_point_kw=(;),
    show_current_point=false,
)
    # TODO first plot as a line and switch to a polygon when you close it to the first point.
    # This will need all new polygons to be a line stored in a separate Observable
    # that we plot like LineString.
    p = if isnothing(c.color)
        poly!(ax, c.geoms)
    else
        poly!(ax, c.geoms; color=c.color, poly_kw...)
    end
    translate!(p, 0, 0, 98)
    draw_points!(fig, ax, c; scatter_kw)
    if show_current_point
        draw_current_point!(fig, ax, c; scatter_kw) 
    end
end
function draw!(fig, ax::Axis, c::GeometryCanvas{<:MultiPoint};
    scatter_kw=(;), lines_kw=(;), poly_kw=(;), current_point_kw=(;),
    show_current_point=false,
)
    translate!(p, 0, 0, 98)
    draw_points!(fig, ax, c; scatter_kw)
    if show_current_point
        draw_current_point!(fig, ax, c; scatter_kw) 
    end
end

function draw_points!(fig, ax::Axis, c::GeometryCanvas; 
    scatter_kw=(;),
)
    # All points
    s = if isnothing(c.color)
        scatter!(ax, c.geoms; scatter_kw...)
    else
        scatter!(ax, c.geoms; color=c.color, scatter_kw...)
    end
    translate!(s, 0, 0, 98)
end

function draw_current_point!(fig, ax::Axis, c::GeometryCanvas; 
    scatter_kw=(;),
)
    # Current point
    current_point_pos = lift(c.points) do points
        cp = c.current_point[]
        length(points) > 0 || return Point2(0.0f0, 0.0f0)
        if cp isa Tuple
            points[cp[1]][cp[2]]
        else
            points[cp]
        end
    end
    p = scatter!(ax, current_point_pos; color=:red, scatter_kw...)
    translate!(p, 0, 0, 100)
end

# Point selection and movement
function add_events!(c::GeometryCanvas{<:Point};
    mouse_property=nothing,
)
    fig = c.figure; ax = c.axis 
    deleting = Observable(false)

    # Set how close to a point we have to be to select it
    accuracy = _accuracy(ax, c.accuracy_scale)

    # Mouse down event
    on(events(ax.scene).mousebutton, priority=100) do event
        # If this canvas is not active dont respond to mouse events
        (; geoms, points, dragging, active, section) = c
        active[] || return Consume(false)

        idx = c.current_point

        # Get mouse position in the axis and figure
        axis_pos = Makie.mouseposition(ax.scene)

        # Add points with left click
        if event.action == Mouse.press
            if Makie.mouseposition_px(fig.scene) in ax.scene.px_area[]
                if _is_alt_pressed(fig)
                    deleting[] = true
                    found = _pointnear(c.points[], axis_pos, accuracy[] * 2) do I
                        _delete_point!(c.points, idx, I)
                        true
                    end
                    notify(points)
                    notify(idx)
                    return Consume(true)
                end
                found = _pointnear(points[], axis_pos, accuracy[]) do i
                    idx[] = i
                    true
                end
                if !found
                    push!(points[], axis_pos)
                    isnothing(mouse_property) || push!(c.properties[mouse_property][], Int(event.button))
                    idx[] = lastindex(points[])
                    notify(points)
                    isnothing(mouse_property) || notify(c.properties[mouse_property])
                end
                dragging[] = true
                return Consume(true)
                return Consume(true)
            end
        elseif event.action == Mouse.release
            if Makie.mouseposition_px(fig.scene) in ax.scene.px_area[]
                dragging[] = false
                return Consume(true)
            end
        end
        return Consume(dragging[])
    end

    # Mouse drag event
    on(events(fig).mouseposition, priority=100) do event
        c.active[] || return Consume(false)
        if c.dragging[]
            axis_pos = Makie.mouseposition(ax.scene)
            c.points[][c.current_point[]] = axis_pos
            # notify(idx)
            notify(c.points)
            return Consume(true)
        end
        return Consume(false)
    end

    on(events(ax.scene).keyboardbutton, priority=100) do event
        (; geoms, points, active, section) = c
        active[] || return Consume(false)
        (event.action in (Keyboard.press, Keyboard.repeat) && event.key == Keyboard.delete) || return Consume(false)

        idx = c.current_point
        # Delete points with delete
        if length(points[]) > 0
            deleteat!(points[], idx[])
            isnothing(mouse_property) || deleteat!(c.properties[mouse_property][], idx[])
            # Set the current point to the previous one, or 1
            idx[] = max(1, idx[]-1)
            notify(idx)
            notify(points)
            isnothing(mouse_property) || notify(c.properties[mouse_property])
        end
        return Consume(true)
    end
end

function add_events!(c::GeometryCanvas{T};
    mouse_property=nothing,
) where T <: Union{<:Polygon,<:LineString,<:MultiPoint}
    fig = c.figure; ax = c.axis 

    deleting = Observable(false)
    accuracy = _accuracy(ax, c.accuracy_scale)

    # Mouse down event
    on(events(ax.scene).mousebutton, priority=100) do event
        (; geoms, points, dragging, active, section) = c

        active[] || return Consume(false)

        # c.on_mouse_events(c, event) == Consume(true) && return nothing

        # Set how close to a point we have to be to select it

        idx = c.current_point

        axis_pos = Makie.mouseposition(ax.scene)
        # Add points with left click
        if event.action == Mouse.press && Makie.mouseposition_px(fig.scene) in ax.scene.px_area[]
            insert = false
            if _is_alt_pressed(fig)
                deleting[] = true
                found = true
                while found 
                    found = _pointnear(c.points[], axis_pos, accuracy[] * 2) do I
                        _delete_point!(c.points, idx, I)
                        true
                    end
                end
                notify(points)
                notify(idx)
                return Consume(true)
            elseif _is_shift_pressed(fig)
                push!(points[], [axis_pos])
                idx[] = (lastindex(points[]), 1)
                found = true
            else
                # See if the click is near a point
                found = _pointnear(points[], axis_pos, accuracy[]) do I
                    idx[] = I
                    true
                end
            end

            # If we didn't find a point close enough
            if !found
                if length(points[]) > 0 && idx[][1] > 0 && length(points[][idx[][1]]) > 1
                    # Search backwards so we preference recent lines
                    for i in eachindex(points[])[end:-1:1]
                        prevp = points[][i][end]
                        for j in eachindex(points[][i])[end-1:-1:1]
                            curp = points[][i][j]
                            line = Line(prevp, curp)
                            # TODO find the closest line not the first
                            if T <: Union{LineString,Polygon} && _ison(line, axis_pos, accuracy[] * 1000)
                                insert = true
                                idx[] = (i, j + 1)
                                insert!(points[][i], j + 1, axis_pos)
                                break
                            end
                            prevp = curp
                        end
                        j = lastindex(points[][i])
                        line = Line(points[][i][j], points[][i][1])
                        if T <: Union{LineString,Polygon} && _ison(line, axis_pos, accuracy[] * 1000)
                            insert = true
                            idx[] = (i, j)
                            push!(points[][i], axis_pos)
                            break
                        end
                    end
                end
                if !insert
                    if length(points[]) > 0
                        i = idx[][1]
                        if i == 0
                            idx[] = (1, 1)
                        elseif idx[][2] > length(points[][i])
                            idx[] = (i, length(points[][i]) + 1)
                        else
                            idx[] = (i, idx[][2] + 1)
                        end
                        insert!(points[][idx[][1]], idx[][2], axis_pos)
                    else
                        idx[] = (1, 1)
                        push!(points[], [axis_pos])
                    end
                end
            end
            dragging[] = true
        elseif event.action == Mouse.release
            deleting[] = false
            dragging[] = false
        end
        notify(points)
        notify(idx)
        return Consume(dragging[])
    end

    # Mouse drag event
    on(events(fig).mouseposition, priority=100) do mp
        c.active[] || return Consume(false)
        idx = c.current_point
        axis_pos = Makie.mouseposition(ax.scene)
        if deleting[] && _is_alt_pressed(fig)
            found = true
            while found 
                found = _pointnear(c.points[], axis_pos, accuracy[]) do I
                    _delete_point!(c.points, idx, I)
                    true
                end
            end
            notify(c.points)
            notify(idx)
            return Consume(true)
        elseif c.dragging[]
            i1, i2 = idx[]
            c.points[][i1][i2] = Point(axis_pos)
            notify(c.points)
            notify(idx)
            return Consume(true)
        end
        return Consume(false)
    end

    # Delete points delete
    on(events(ax.scene).keyboardbutton) do event
        (; geoms, points, active, section) = c

        active[] || return Consume(false)
        (event.action in (Keyboard.press, Keyboard.repeat) && event.key == Keyboard.delete) || return Consume(false)

        idx = c.current_point
        i1, i2 = idx[]
        if _is_shift_pressed(fig)
            length(points[]) > 0 || return Consume(true)
            # Delete whole polygon
            deleteat!(points[], i1)
            idx[] = (max(1, i1 - 1), 1)
        else
            length(points[][i1]) > 0 || return Consume(true)
            # Delete point 
            _delete_point!(points, idx, idx[])
        end
        notify(idx)
        notify(points)
        return Consume(true)
    end
end

function _delete_point!(points, idx::Observable{<:Tuple}, I)
    i1, i2 = I
    deleteat!(points[][i1], i2)
    idx[] = (i1, lastindex(points[][i1]))
    if length(points[][i1]) == 0
        deleteat!(points[], i1)
        if length(points[]) > 0
            s = max(1, i1 - 1)
            idx[] = (s, lastindex(points[][s]))
        else
            idx[] = (0, 0)
        end
    end
    return nothing
end
function _delete_point!(points, idx::Observable{Int}, i::Int)
    deleteat!(points[], i)
    idx[] = i - 1
    return nothing
end

# Get pixel click accuracy from the size of the visable heatmap.
function _accuracy(ax::Axis, accuracy_scale)
    lift(ax.finallimits) do fl
        maximum(fl.widths) / 100 * accuracy_scale
    end
end

geoms_to_points(geoms) = 
    [[Point2(GI.x(p), GI.y(p)) for p in GI.getpoint(g)] for g in geoms]
