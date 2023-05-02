"""
    PaintCanvas{T<:GeometryBasics.Geometry}

    PaintCanvas{T}(geoms=T[]; kw...)

A canvas for painting into a Matrix Real numbers or colors.
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
    on_mouse_events::Function
end
function PaintCanvas(data;
    f=heatmap!,
    drawing=Observable{Bool}(false),
    active=Observable{Bool}(true),
    name=nameof(typeof(data)),
    dimensions=axes(data),
    fill_left=Observable(oneunit(eltype(data))),
    fill_right=Observable(zero(eltype(data))),
    figure=Figure(),
    axis=Axis(fig[1, 1]),
    on_mouse_events=no_consume,
)
    obs_args = map(_as_observable, (drawing, active, dimensions, data, fill_left, fill_right))
    c = PaintCanvas{eltype(data),typeof(f),typeof(dimensions),typeof(data),typeof(figure),typeof(axis)
                   }(f, obs_args..., name, figure, axis, on_mouse_events)
    draw!(figure, axis, c)
    return c
end
PaintCanvas(f, data; kw...) = PaintCanvas(data; f, kw...) 

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
        c.on_mouse_events(c, event) == Consume(false) || return

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
            fig_pos = Makie.mouseposition_px(fig.scene)
            axis_pos = Makie.mouseposition(ax.scene)
            if !(fig_pos in ax.scene.px_area[])
                drawing[] = false
                return Consume(false)
            end
            fill = drawleft[] ? c.fill_left[] : c.fill_right[]
            line = (start=(x=lastpos[][2], y=lastpos[][1]),
                    stop=(x=axis_pos[2], y=axis_pos[1]))
            paint_line!(c.data[], c.dimensions[]..., fill, line)
            notify(c.data)
            lastpos[] = axis_pos
            return Consume(true)
        end
        return Consume(false)
    end
end

function paint!(c, fill, pos)
    I = round.(Int, Tuple(pos))
    if checkbounds(Bool, c.data[], I...)
        @inbounds c.data[][I...] = fill
    end
    notify(c.data)
end

# Bresenham algorithm copied from Rasters.jl
# maybe there should be a package for this...
function paint_line!(A, ys, xs, fill, line)
    raster_x_step = step(xs)
    raster_y_step = step(ys)
    raster_x_offset = @inbounds xs[1] - raster_x_step / 2 # Shift from center to start of pixel
    raster_y_offset = @inbounds ys[1] - raster_y_step / 2
    # Converted lookup to array axis values (still floating)
    relstart = (x=(line.start.x - raster_x_offset) / raster_x_step,
             y=(line.start.y - raster_y_offset) / raster_y_step)
    relstop = (x=(line.stop.x - raster_x_offset) / raster_x_step,
            y=(line.stop.y - raster_y_offset) / raster_y_step)
    diff_x = relstop.x - relstart.x
    diff_y = relstop.y - relstart.y

    # Ray/Slope calculations
    # Straight distance to the first vertical/horizontal grid boundaries
    if relstop.x > relstart.x
        xoffset = floor(relstart.x) - relstart.x + 1
        xmoves = floor(Int, relstop.x) - floor(Int, relstart.x)
    else
        xoffset = relstart.x - floor(relstart.x)
        xmoves = floor(Int, relstart.x) - floor(Int, relstop.x)
    end
    if relstop.y > relstart.y
        yoffset = floor(relstart.y) - relstart.y + 1
        ymoves = floor(Int, relstop.y) - floor(Int, relstart.y)
    else
        yoffset = relstart.y - floor(relstart.y)
        ymoves = floor(Int, relstart.y) - floor(Int, relstop.y)
    end
    manhattan_distance = xmoves + ymoves
    # Angle of ray/slope.
    # max: How far to move along the ray to cross the first cell boundary.
    # delta: How far to move along the ray to move 1 grid cell.
    hyp = @fastmath sqrt(diff_y^2 + diff_x^2)
    cs = diff_x / hyp
    si = -diff_y / hyp

    delta_x, max_x =# if isapprox(cs, zero(cs); atol=1e-10)
        # -Inf, Inf
    # else
        1.0 / cs, xoffset / cs
    # end
    delta_y, max_y =# if isapprox(si, zero(si); atol=1e-10)
        # -Inf, Inf
    # else
        1.0 / si, yoffset / si
    # end
    # For arbitrary dimension indexing
    # Count how many exactly hit lines
    n_on_line = 0
    countx = county = 0

    # Int starting points for the lin. +1 converts to julia indexing
    j, i = floor(Int, relstart.x) + 1, floor(Int, relstart.y) + 1 # Int

    # Int steps to move allong the line
    step_j = signbit(diff_x) * -2 + 1
    step_i = signbit(diff_y) * -2 + 1

    # Travel one grid cell at a time. Start at zero for the current cell
    for _ in 0:manhattan_distance
        if checkbounds(Bool, A, i, j...)
            @inbounds A[i, j] = fill
        end

        # Only move in either X or Y coordinates, not both.
        if abs(max_x) < abs(max_y)
            max_x += delta_x
            j += step_j
            countx +=1
        else
            max_y += delta_y
            i += step_i
            county +=1
        end
    end
    return n_on_line
end
