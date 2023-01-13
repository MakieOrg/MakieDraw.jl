module MakieDraw

using GeometryBasics, Makie

export Canvas, draw!

"""
    Canvas{T<:GeometryBasics.Geometry}

A canvas for drawing GeometryBasics.jl geometries onto a Makie.jl `Axis`.
"""
struct Canvas{T,G,P,CP,I}
    geoms::G
    points::P
    dragging::Observable{Bool}
    active::Observable{Bool}
    accuracy_scale::Float64
    current_point::CP
    section::I
    name::Symbol
end
function Canvas{T}(geoms=T[];
    dragging=Observable(false),
    active=Observable(true),
    accuracy_scale=1.0,
    name=nameof(T),
) where T
    # Convert geometries to nested points vectors so theyre easier to search and manipulate
    if T <: Point
        points_obs = Observable([Point(0.0f0, 0.0f0)]) # _to_points(geoms)
    else
        points_obs = Observable([[Point(0.0f0, 0.0f0)]]) # _to_points(geoms)
    end
    # And convert back to the target geometry with `lift`
    if T isa Point
        geoms_obs = points_obs
        section = nothing
    elseif T isa LineString
        # ps will be a Vector of Vector of Point
        section = nothing
        geoms_obs = lift(points_obs) do ps
            geoms = LineString.(ps)
            geoms
        end
    else
        # ps will be a Vector of Vector of Point
        # TODO support exteriors and holes with another layer of nesting?
        # Maybe Alt+click could mean "drawing a hole in this polygon now"
        # And section would be 1 here
        section = nothing
        geoms_obs = lift(points_obs) do ps
            T.(ps)
        end
    end

    # Tracking the current point so it can be a different color
    current_point = Point2(-1, -1)

    Canvas{T,typeof(geoms_obs),typeof(points_obs),typeof(current_point),typeof(section)}(
        geoms_obs, points_obs, dragging, active, accuracy_scale, current_point, section, name
    )
end


function draw!(c::Canvas{<:Point}, fig, ax::Axis)
    scatter!(ax, c.geoms)
    dragselect!(c, fig, ax)
    addtoswitchers!(fig, ax, c)
end
function draw!(c::Canvas{<:LineString}, fig, ax::Axis)
    scatter!(ax, c.geoms)
    lines!(ax, c.geoms)
    dragselect!(c, fig, ax)
    addtoswitchers!(fig, ax, c)
end
function draw!(c::Canvas{<:Polygon}, fig, ax::Axis)
    scatter!(ax, c.geoms)
    # TODO first plot as a line and switch to a polygon when you close it to the first point.
    # This will need all new polygons to be a line stored in a separate Observable
    # that we plot like LineString.
    poly!(ax, c.geoms)
    dragselect!(c, fig, ax)
    addtoswitchers!(fig, ax, c)
end

# Get pixel click accuracy from the size of the visable heatmap.
function _accuracy(ax::Axis, accuracy_scale)
    lift(ax.finallimits) do fl
        maximum(fl.widths) / 100 * accuracy_scale
    end
end

function dragselect!(c::Canvas{<:Point}, fig::Figure, ax::Axis)
    (; geoms, points, dragging, active, section, accuracy_scale) = c

    # Set how close to a point we have to be to select it
    accuracy = _accuracy(ax, accuracy_scale)

    idx = Ref(0)
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
                            notify(points)
                        end
                    end
                    dragging[] = true
                end
            elseif event.action == Mouse.release
                dragging[] = false
                notify(points)
            end
        # Delete points with right click
        elseif event.button == Mouse.right
            if pos_px in ax.scene.px_area[]
                _pointnear(_get(points, section), pos, accuracy[]) do i
                    isnothing(i) || deleteat!(_get(points, section), i)
                    notify(points)
                end
            end
        end
        return Consume(dragging[])
    end

    # Mouse drag event
    on(events(fig).mouseposition, priority = 2) do mp
        active[] || return Consume(false)
        if dragging[]
            pos = Makie.mouseposition(ax.scene)
            _get(points, section)[idx[]] = pos
            notify(points)
            return Consume(true)
        end
        return Consume(false)
    end
end

function dragselect!(c::Canvas{T}, fig, ax) where T <: Union{<:Polygon,<:LineString}
    (; geoms, points, dragging, active, section, accuracy_scale) = c

    # Set how close to a point we have to be to select it
    accuracy = _accuracy(ax, accuracy_scale)

    idx = Ref((0, 0))

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
                            i = idx[][1]
                            lastp = cur_geom[end][end]
                            for j in eachindex(cur_geom[i])[end-1:-1:1]
                                p = cur_geom[i][j]
                                online = _ison(Line(lastp, p), pos, accuracy[] * 2)
                                if online
                                    insert = true
                                    idx[] = (i, j + 1)
                                    insert!(cur_geom[i], j + 1, pos)
                                    notify(points)
                                    break
                                end
                                lastp = p
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
                            notify(points)
                        end
                    end
                    dragging[] = true
                end
            elseif event.action == Mouse.release
                dragging[] = false
                notify(points)
            end

        # Delete points with right click
        elseif event.button == Mouse.right
            cur_geom = _get(points, section)
            if _is_shift_pressed(fig)
                for i in eachindex(points[])
                    if pos in cur_geom[i]
                        deleteat!(cur_geom, i)
                        idx[] = (1, 1)
                        notify(points)
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
                        notify(points)
                    end
                end
            end
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

function _pointnear(f, positions::Vector{<:Point}, pos, accuracy)
    for i in eachindex(positions)[end:-1:1]
        p = positions[i]
        if p[1] in (pos[1]-accuracy..pos[1]+accuracy) &&
            p[2] in (pos[2]-accuracy..pos[2]+accuracy)
            return f(i)
        end
    end
    return nothing
end

function _pointnear(f, positions::Vector{<:Vector}, pos, accuracy)
    for i in eachindex(positions)[end:-1:1]
        for j in eachindex(positions[i])
            p = positions[i][j]
            if p[1] in (pos[1]-accuracy..pos[1]+accuracy) &&
                p[2] in (pos[2]-accuracy..pos[2]+accuracy)
                return f((i, j))
            end
        end
    end
    return nothing
end


function _ison(line, point, accuracy)
    (x1, y1), (x2, y2) = line
    x = point[1]
    y = point[2]
    grad = (y2 - y1) / (x2 - x1)
    if grad in (Inf, -Inf, NaN, NaN32)
        return x2 == x && inbounds((y1, y2), y)
    elseif grad == 0
        return y2 == y && inbounds((x1, x2), x)
    else
        inbounds((y1, y2), y) && inbounds((x1, x2), x) || return false
        if grad > -1 && grad < 1
            line_y = round(grad * (x - x1) + y1)
            return y in (line_y - accuracy)..(line_y + accuracy)
        else
            line_x = round((y - y1)/grad + x1)
            return x in (line_x - accuracy)..(line_x + accuracy)
        end
    end
end

inbounds((x1, x2), x) = x >= min(x1, x2) && x <= max(x1, x2)

_get(positions::Observable, section) = _get(positions[], section)
_get(positions::Vector, section::Observable) = _get(positions, section[])
_get(positions::Vector, section::Int) = positions[section]
_get(positions::Vector, ::Nothing) = positions

function _is_shift_pressed(fig)
    pressed = events(fig).keyboardstate
    Makie.Keyboard.left_shift in pressed || Makie.Keyboard.right_shift in pressed
end

abstract type AbstractCanvasSelect <: Makie.Block end

struct CanvasSelect{L} <: AbstractCanvasSelect 
    layers::L
    menu::Menu
    axis::Axis
end
function CanvasSelect(m::Menu, ax::Axis; layers=Dict{Symbol,Observable{Bool}}())
    on(m.selection) do selected
        @show selected
        for (key, active) in layers 
            active[] = key == Symbol(selected)
            notify(active)
        end
    end
    CanvasSelect(layers, m, ax)
end
function CanvasSelect(fig::Union{Figure,GridPosition}, ax::Axis; layers=[])
    m = Menu(fig; options=collect(keys(layers)))
    CanvasSelect(m, ax; layers)
end

layers(ls::AbstractCanvasSelect) = ls.layers

Base.push!(ls::AbstractCanvasSelect, x::Pair{Symbol,Observable{Bool}}) = push!(layers(ls), x)
Base.getindex(ls::AbstractCanvasSelect, key::Symbol) = layers(ls)[key]
Base.setindex!(ls::AbstractCanvasSelect, x::Observable{Bool}, key::Symbol) = layers(ls)[key] = x

function addtoswitchers!(fig, ax::Axis, c::Canvas)
    for x in fig.content
        # Find all AbstractCanvasSelect on this Axis
        if x isa AbstractCanvasSelect# && x.axis == ax
            if haskey(x, c.name)
                # Add the first number to the name that doesn't exist yet
                i = 1
                while true
                    key = Symbol(c.name, i)
                    if !haskey(x, key)
                        x[key] = c.active
                        break
                    end
                end
            else
                x[c.name] = c.active
            end
        end
    end
end

end

