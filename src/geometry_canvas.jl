"""
    GeometryCanvas{T<:GeometryBasics.Geometry}

    GeometryCanvas{T}(geoms=T[]; kw...)

A canvas for drawing GeometryBasics.jl geometries onto a Makie.jl `Axis`.

`T` must be `Point`, `LineString` or `Polygon`.
"""
mutable struct GeometryCanvas{T,G,P,CP,I,Pr,TB,F,A} <: AbstractCanvas
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
    fig::F
    axis::A
end
function GeometryCanvas(obj; properties=nothing, kw...)
    if GI.isfeaturecollection(obj)
        if properties isa NTuple{<:Any,Symbol}
            properties = map(properties) do key
                String[getproperty(GI.properties(f), key) for f in GI.getfeature(obj)]
            end |> NamedTuple{properties}
        end
        geoms = filter(map(GI.geometry, GI.getfeature(obj))) do geom
            !isnothing(geom)
        end
    else
        geoms = obj
    end
    gb_geoms = GI.convert.(Ref(GeometryBasics), geoms)
    trait = GI.geomtrait(first(gb_geoms))
    T = GeometryBasics.geointerface_geomtype(trait)
    GeometryCanvas{T}(gb_geoms; properties, kw...)
end
function GeometryCanvas{T}(geoms=T[];
    dragging=Observable(false),
    active=Observable(true),
    accuracy_scale=1.0,
    name=nameof(T),
    properties=(),
    fig=Figure(),
    axis=Axis(fig[1:10, 1:10]),
) where T
    axis.aspect = AxisAspect(1)
    properties = if properties isa Tuple
        map(properties) do p
            Observable(String[" " for _ in geoms])
        end |> NamedTuple{properties}
    elseif properties isa NamedTuple
        map(properties) do p
            Observable(p)
        end
    else
        throw(ArgumentError("Properties must be a Tuple of `Symbol` or a NamedTuple of `Vector{String}`"))
    end
    # Convert geometries to nested points vectors so theyre easier to search and manipulate
    if T <: Point
        points_obs = Observable([Point(0.0f0, 0.0f0)]) 
    else
        if length(geoms) > 0
            points_obs = Observable(map(collect ∘ GI.getpoint, geoms))
        else
            points_obs = Observable([[Point(0.0f0, 0.0f0)]]) # _to_points(geoms)
        end
    end
    # And convert back to the target geometry with `lift`
    if T isa Point
        geoms_obs = points_obs
        section = nothing
        current_point = Observable(1)
    elseif T isa LineString
        # ps will be a Vector of Vector of Point
        section = nothing
        geoms_obs = lift(points_obs) do ps
            geoms = LineString.(ps)
            geoms
        end
        current_point = Observable((1, 1))
    else
        # ps will be a Vector of Vector of Point
        # TODO support exteriors and holes with another layer of nesting?
        # Maybe Alt+click could mean "drawing a hole in this polygon now"
        # And section would be 1 here
        section = nothing
        geoms_obs = lift(points_obs) do ps
            T.(ps)
        end
        current_point = Observable((1, 1))
    end

    i = 0
    text_boxes = map(properties) do props
        i += 1
        tb = Textbox(fig[11, i]; stored_string=" ")
        on(tb.stored_string) do t
            propsvec = props[]
            for i in 1:c.current_point[][1]-length(propsvec)
                push!(propsvec, " ")
            end
            props[][current_point[][1]] = t
            # notify(props)
        end
        on(current_point) do cp
            propsvec = props[]
            for i in 1:cp[1]-length(propsvec)
                push!(propsvec, " ")
            end
            tb.displayed_string[] = lpad(props[][cp[1]], 1)
            # notify(tb.displayed_string)
        end
    end

    canvas = GeometryCanvas{T,typeof(geoms_obs),typeof(points_obs),typeof(current_point),typeof(section),typeof(properties),typeof(text_boxes),typeof(fig),typeof(axis)}(
        geoms_obs, points_obs, dragging, active, accuracy_scale, current_point, section, name, properties, text_boxes, fig, axis
    )

    # Plot everying on `axis`
    draw!(canvas, fig, axis)
    return canvas
end

# Base methods
Base.display(c::GeometryCanvas) = display(c.fig)

# GeoInterface.jl methods
GI.isfeaturecollection(::Type{<:GeometryCanvas}) = true
GI.trait(::GeometryCanvas) = GI.FeatureCollectionTrait()
GI.nfeature(::GI.FeatureCollectionTrait, c::GeometryCanvas) = length(c.geoms[])
function GI.getfeature(::GI.FeatureCollectionTrait, c::GeometryCanvas, i)
    properties = map(p -> p[][i], c.properties)
    GI.Feature(c.geoms[][i]; properties)
end

# Tables.jl methods
# TODO

# Ploting 
function draw!(c::GeometryCanvas{<:Point}, fig, ax::Axis)
    _draw_points!(c, fig, ax)
    addtoswitchers!(fig, ax, c)
end
function draw!(c::GeometryCanvas{<:LineString}, fig, ax::Axis)
    l = lines!(ax, c.geoms)
    translate!(l, 0, 0, 98)
    # End points 
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
    e = scatter!(ax, end_points; color=:black)
    translate!(e, 0, 0, 99)

    _draw_points!(c, fig, ax)
    addtoswitchers!(fig, ax, c)
end
function draw!(c::GeometryCanvas{<:Polygon}, fig, ax::Axis)
    # TODO first plot as a line and switch to a polygon when you close it to the first point.
    # This will need all new polygons to be a line stored in a separate Observable
    # that we plot like LineString.
    p = poly!(ax, c.geoms)
    translate!(p, 0, 0, 98)
    _draw_points!(c, fig, ax)
    addtoswitchers!(fig, ax, c)
end

function _draw_points!(c::GeometryCanvas, fig, ax::Axis)
    # All points
    s = scatter!(ax, c.geoms)
    translate!(s, 0, 0, 98)

    # Current point
    current_point_pos = lift(c.points) do points
        cp = c.current_point[]
        if cp isa Tuple
            points[cp[1]][cp[2]]
        else
            points[cp]
        end
    end
    p = scatter!(ax, current_point_pos)
    translate!(p, 0, 0, 100)

    # Add mouse events
    mouse_drag!(c, fig, ax)
end

# Point selection and movement
function mouse_drag!(c::GeometryCanvas{<:Point}, fig::Figure, ax::Axis)
    (; geoms, points, dragging, active, section, accuracy_scale) = c

    # Set how close to a point we have to be to select it
    accuracy = _accuracy(ax, accuracy_scale)

    idx = c.current_point
    # Mouse down event
    on(events(fig).mousebutton, priority = 2) do event
        # If this canvas is not active dont respond to mouse events
        active[] || return Consume(false)

        # Get mouse position in the axis and figure
        pos = Makie.mouseposition(ax.scene)
        pos_px = Makie.mouseposition_px(fig.scene)

        # Add points with left click
        if event.button == Mouse.left
            if event.action == Mouse.press
                if pos_px in ax.scene.px_area[]
                    insert = false
                    found = _pointnear(_get(points, section), pos, accuracy[]) do i
                        if isnothing(i)
                            return nothing
                        else
                            idx[] = i
                            true
                        end
                    end
                    if isnothing(found)
                        if !insert
                            push!(_get(points, section), pos)
                            idx[] = lastindex(_get(points, section))
                        end
                    end
                    dragging[] = true
                end
            elseif event.action == Mouse.release
                dragging[] = false
            end
        # Delete points with right click
        elseif event.button == Mouse.right
            if pos_px in ax.scene.px_area[]
                _pointnear(_get(points, section), pos, accuracy[]) do i
                    isnothing(i) || deleteat!(_get(points, section), i)
                end
            end
        end
        notify(idx)
        notify(points)
        return Consume(dragging[])
    end

    # Mouse drag event
    on(events(fig).mouseposition, priority = 2) do mp
        active[] || return Consume(false)
        if dragging[]
            pos = Makie.mouseposition(ax.scene)
            _get(points, section)[idx[]] = pos
            notify(idx)
            notify(points)
            return Consume(true)
        end
        return Consume(false)
    end
end
function mouse_drag!(c::GeometryCanvas{T}, fig, ax) where T <: Union{<:Polygon,<:LineString}
    (; geoms, points, dragging, active, section, accuracy_scale) = c

    # Set how close to a point we have to be to select it
    accuracy = _accuracy(ax, accuracy_scale)

    idx = c.current_point

    # Mouse down event
    on(events(fig).mousebutton, priority = 2) do event
        active[] || return Consume(false)
        pos = Makie.mouseposition(ax.scene)
        pos_px = Makie.mouseposition_px(fig.scene)
        # Add points with left click
        if event.button == Mouse.left
            cur_geom = _get(points, section)
            if event.action == Mouse.press
                if pos_px in ax.scene.px_area[]
                    insert = false
                    if _is_shift_pressed(fig)
                        push!(points[], [pos])
                        idx[] = (lastindex(cur_geom), 1)
                    end
                    # See if the click is near a point
                    found = _pointnear(points[], pos, accuracy[]) do I
                        if isnothing(I)
                            return nothing
                        else
                            idx[] = I
                            return true
                        end
                    end

                    # If we didn't find a point close enough
                    if isnothing(found)
                        if length(cur_geom) > 0 && idx[][1] > 0 && length(cur_geom[idx[][1]]) > 1
                            # Search backwards so we preference recent lines
                            for i in eachindex(cur_geom)[end:-1:1]
                                prevp = cur_geom[i][end]
                                for j in eachindex(cur_geom[i])[end-1:-1:1]
                                    curp = cur_geom[i][j]
                                    line = Line(prevp, curp)
                                    # TODO find the closest line not the first
                                    online = _ison(line, pos, accuracy[] * 1000)
                                    if online
                                        insert = true
                                        idx[] = (i, j + 1)
                                        insert!(cur_geom[i], j + 1, pos)
                                        break
                                    end
                                    prevp = curp
                                end
                            end
                        end
                        if !insert
                            if length(cur_geom) > 0
                                i = idx[][1]
                                if i == 0
                                    idx[] = (1, 1)
                                elseif idx[][2] > length(cur_geom[i])
                                    idx[] = (i, length(cur_geom[i]) + 1)
                                else
                                    idx[] = (i, idx[][2] + 1)
                                end
                                insert!(cur_geom[idx[][1]], idx[][2], pos)
                            else
                                idx[] = (1, 1)
                                push!(cur_geom, [pos])
                            end
                        end
                    end
                    dragging[] = true
                end
            elseif event.action == Mouse.release
                dragging[] = false
            end
            notify(points)
            notify(idx)
        # Delete points with right click
        elseif event.button == Mouse.right
            cur_geom = _get(points, section)
            if _is_shift_pressed(fig)
                for i in eachindex(points[])
                    if pos in cur_geom[i]
                        deleteat!(cur_geom, i)
                        idx[] = (1, 1)
                        break
                    end
                end
            elseif pos_px in ax.scene.px_area[]
                _pointnear(cur_geom, pos, accuracy[]) do I
                    if !isnothing(I)
                        deleteat!(cur_geom[I[1]], I[2])
                        idx[] = (I[1], lastindex(cur_geom[I[1]]))
                        if length(cur_geom[I[1]]) == 0
                            deleteat!(cur_geom, I[1])
                            if length(cur_geom) > 0
                                s = max(1, I[1] - 1)
                                idx[] = (s, lastindex(cur_geom[s]))
                            else
                                idx[] = (0, 0)
                            end
                        end
                    end
                end
            end
            notify(idx)
            notify(points)
        end
        return Consume(dragging[])
    end

    # Mouse drag event
    on(events(fig).mouseposition, priority = 2) do mp
        active[] || return Consume(false)
        if dragging[]
            pos = Makie.mouseposition(ax.scene)
            cur_polygon = _get(points, section)
            cur_polygon[idx[][1]][idx[][2]] = Point(pos)
            notify(points)
            return Consume(true)
        end
        return Consume(false)
    end
end

# Get pixel click accuracy from the size of the visable heatmap.
function _accuracy(ax::Axis, accuracy_scale)
    lift(ax.finallimits) do fl
        maximum(fl.widths) / 100 * accuracy_scale
    end
end

_get(positions::Observable, section) = _get(positions[], section)
_get(positions::Vector, section::Observable) = _get(positions, section[])
_get(positions::Vector, section::Int) = positions[section]
_get(positions::Vector, ::Nothing) = positions
