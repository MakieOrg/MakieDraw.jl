"""
    GeometryCanvas{T<:GeometryBasics.Geometry}

    GeometryCanvas{T}(geoms=T[]; kw...)

A canvas for drawing GeometryBasics.jl geometries onto a Makie.jl `Axis`.

`T` must be `Point`, `LineString` or `Polygon`.
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
            Makie.Observables.observe(p)
        end
    else
        nothing
    end

    text_boxes = if isnothing(properties) || !text_input
        nothing
    else
        _make_property_text_inputs(figure, properties, current_point)
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

function _make_property_text_inputs(fig, properties::NamedTuple, current_point::Observable)
    i = 0
    map(properties) do props
        i += 1
        tb = Textbox(fig[11, i]; stored_string=" ")
        T = eltype(props[])
        on(tb.stored_string) do t
            propsvec = props[]
            for i in 1:current_point[][1]-length(propsvec)
                if T isa AbstractString
                    push!(propsvec, " ")
                elseif T isa Real
                    push!(propsvec, zero(T))
                end
            end
            propsvec[current_point[][1]] = t
            notify(props)
        end
        on(current_point) do cp
            propsvec = props[]
            for i in 1:cp[1]-length(propsvec)
                if T isa AbstractString
                    push!(propsvec, " ")
                elseif T isa Real
                    push!(propsvec, zero(T))
                end
            end
            tb.displayed_string[] = lpad(propsvec[cp[1]], 1)
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
    # Mouse down event
    on(events(ax.scene).mousebutton, priority=100) do event
        # If this canvas is not active dont respond to mouse events
        (; geoms, points, dragging, active, section, accuracy_scale) = c
        active[] || return Consume(false)

        # Set how close to a point we have to be to select it
        accuracy = _accuracy(ax, accuracy_scale)

        idx = c.current_point

        # Get mouse position in the axis and figure
        axis_pos = Makie.mouseposition(ax.scene)

        # Add points with left click
        if event.action == Mouse.press
            if Makie.mouseposition_px(fig.scene) in ax.scene.px_area[]
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

    on(events(fig).keyboardbutton, priority=100) do event
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

    # Mouse down event
    on(events(ax.scene).mousebutton, priority=100) do event
        (; geoms, points, dragging, active, section, accuracy_scale) = c

        active[] || return Consume(false)

        # c.on_mouse_events(c, event) == Consume(true) && return nothing

        # Set how close to a point we have to be to select it
        accuracy = _accuracy(ax, accuracy_scale)

        idx = c.current_point

        pos = Makie.mouseposition(ax.scene)
        # Add points with left click
        if event.action == Mouse.press && Makie.mouseposition_px(fig.scene) in ax.scene.px_area[]
            insert = false
            if _is_alt_pressed(fig)
                deleting[] = true
                found = true
                while found 
                    found = _pointnear(c.points[], pos, c.accuracy_scale[] * 2) do I
                        idx[] = I
                        _delete_point!(c.points, idx)
                        true
                    end
                end
                notify(points)
                notify(idx)
                return Consume(true)
            elseif _is_shift_pressed(fig)
                push!(points[], [pos])
                idx[] = (lastindex(points[]), 1)
                found = true
            else
                # See if the click is near a point
                found = _pointnear(points[], pos, accuracy[]) do I
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
                            if T <: Union{LineString,Polygon} && _ison(line, pos, accuracy[] * 1000)
                                insert = true
                                idx[] = (i, j + 1)
                                insert!(points[][i], j + 1, pos)
                                break
                            end
                            prevp = curp
                        end
                        j = lastindex(points[][i])
                        line = Line(points[][i][j], points[][i][1])
                        if T <: Union{LineString,Polygon} && _ison(line, pos, accuracy[] * 1000)
                            insert = true
                            idx[] = (i, j)
                            push!(points[][i], pos)
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
                        insert!(points[][idx[][1]], idx[][2], pos)
                    else
                        idx[] = (1, 1)
                        push!(points[], [pos])
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
        pos = Makie.mouseposition(ax.scene)
        if deleting[] && _is_alt_pressed(fig)
            found = true
            while found 
                found = _pointnear(c.points[], pos, c.accuracy_scale[] * 2) do I
                    idx[] = I
                    _delete_point!(c.points, idx)
                    true
                end
            end
            found && _delete_point!(c.points, idx)
            notify(c.points)
            notify(idx)
            return Consume(true)
        elseif c.dragging[]
            i1, i2 = idx[]
            c.points[][i1][i2] = Point(pos)
            notify(c.points)
            notify(idx)
            return Consume(true)
        end
        return Consume(false)
    end

    # Delete points delete
    on(events(fig).keyboardbutton) do event
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
            _delete_point!(points, idx)
        end
        notify(idx)
        notify(points)
        return Consume(true)
    end
end

function _delete_point!(points, idx::Observable{<:Tuple})
    i1, i2 = idx[]
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
end

# Get pixel click accuracy from the size of the visable heatmap.
function _accuracy(ax::Axis, accuracy_scale)
    lift(ax.finallimits) do fl
        maximum(fl.widths) / 100 * accuracy_scale
    end
end

geoms_to_points(geoms) = 
    [[Point2(GI.x(p), GI.y(p)) for p in GI.getpoint(g)] for g in geoms]
