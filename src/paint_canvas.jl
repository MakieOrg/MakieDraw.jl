"""
    PaintCanvas{T<:GeometryBasics.Geometry}

    PaintCanvas{T}(geoms=T[]; kw...)

A canvas for drawing GeometryBasics.jl geometries onto a Makie.jl `Axis`.

`T` must be `Point`, `LineString` or `Polygon`.
"""
mutable struct PaintCanvas{T,Fu,D,M<:AbstractMatrix{T},Fi,A} <: AbstractCanvas
    f::Fu
    drawing::Observable{Bool}
    active::Observable{Bool}
    dimensions::Observable{D}
    data::Observable{M}
    fill_left::Observable{T}
    fill_right::Observable{T}
    name::Symbol
    fig::Fi
    axis::A
end
function PaintCanvas(data; 
    f=heatmap!,
    drawing=Observable{Bool}(false),
    active=Observable{Bool}(true),
    name=nameof(typeof(data)),
    dimensions=axes(data), 
    fill_left=Observable(oneunit(eltype(data))),
    fill_right=Observable(zero(eltype(data))),
    fig=Figure(),
    axis=Axis(fig[1, 1]),
) 
    obs_args = map(_as_observable, (drawing, active, dimensions, data, fill_left, fill_right))
    c = PaintCanvas{eltype(data),typeof(f),typeof(dimensions),typeof(data),typeof(fig),typeof(axis)
                   }(f, obs_args..., name, fig, axis)
    draw!(fig, axis, c)
    return c
end

_as_observable(x) = Observable(x)
_as_observable(x::Observable) = x

Base.display(c::PaintCanvas) = display(c.fig)

function draw!(fig, ax::Axis, c::PaintCanvas)
    c.f(c.axis, c.dimensions[]..., c.data)
    add_mouse_events!(fig, ax, c)
end

function add_mouse_events!(fig::Figure, ax::Axis, c::PaintCanvas)
    lastpos = Observable{Any}()
    drawleft = Observable(true)
    (; drawing, active) = c
    on(events(ax.scene).mousebutton, priority = 100) do event

        # If this canvas is not active dont respond to mouse events
        active[] || return Consume(false)

        @show "click"

        # Get mouse position in the axis and figure
        axis_pos = Makie.mouseposition(ax.scene)
        fig_pos = Makie.mouseposition_px(fig.scene)

        # Add points with left click
        if event.action == Mouse.press
            if !(fig_pos in ax.scene.px_area[])
                drawing[] = false
                return Consume(false)
            end
            lastpos[] = axis_pos
            if event.button == Mouse.left
                @show "paint"
                drawleft[] = true
                paint!(c, c.fill_left[], axis_pos)
                drawing[] = true
                return Consume(true)
            elseif event.button == Mouse.right
                drawleft[] = false
                paint!(c, c.fill_right[], axis_pos)
                drawing[] = true
                return Consume(true)
            end
        elseif event.action == Mouse.release
            drawing[] = false
            return Consume(true)
        end
        return Consume(drawing[])
    end

    # Mouse drag event
    on(events(fig).mouseposition, priority = 100) do event
        active[] || return Consume(false)
        if drawing[]
            axis_pos = Makie.mouseposition(ax.scene)
            fill = drawleft[] ? c.fill_left[] : c.fill_right[]
            paint!(c, fill, axis_pos)
            lastpos[] = axis_pos
            return Consume(true)
        end
        return Consume(false)
    end
end

function paint!(c, fill, pos)
    I = round.(Int, Tuple(pos))
    c.data[][I...] = fill 
    notify(c.data)
end
