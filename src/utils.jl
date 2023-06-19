"""
    arrow_key_navigation(fig, axis)

Allow moving the axis with keyboard arrow keys.
"""
function arrow_key_navigation(fig, axis)
    # Keyboard arrow movement
    scale = lift(axis.finallimits) do fl
        round(Int, maximum(fl.widths) / 10)
    end
    on(events(fig).keyboardbutton) do event
        event.action == Makie.Keyboard.press || return Consume(false)
        s = scale[]
        if event.key == Keyboard.right
            _moveaxis(axis, (s, 0))
        elseif event.key == Keyboard.up
            _moveaxis(axis, (0, s))
        elseif event.key == Keyboard.left
            _moveaxis(axis, (-s, 0))
        elseif event.key == Keyboard.down
            _moveaxis(axis, (0, -s))
        # elseif event.key == Keyboard.tab
            # ispressed(fig) ? _previous_panel(layout, obs) : _next_panel(layout, obs)
        end
        # Let the event reach other listeners
        return Consume(false)
    end
end

function _is_shift_pressed(fig)
    pressed = events(fig).keyboardstate
    Makie.Keyboard.left_shift in pressed || Makie.Keyboard.right_shift in pressed
end

function _is_control_pressed(fig)
    pressed = events(fig).keyboardstate
    Makie.Keyboard.left_control in pressed || Makie.Keyboard.right_control in pressed
end

function _is_alt_pressed(fig)
    pressed = events(fig).keyboardstate
    Makie.Keyboard.left_alt in pressed || Makie.Keyboard.right_alt in pressed
end

function _pointnearest(f, positions::Vector{<:Point}, pos, accuracy)
    length(positions) > 0 || return false
    mindistance = Inf
    minindex = 0
    for i in eachindex(positions)
        p = positions[i]
        distance = sqrt((p[1] - pos[1])^2 + (p[2] - pos[2])^2)
        if distance < mindistance
            mindistance = distance
            minindex = i
        end
    end
    if (mindistance < accuracy) && (minindex != 0)
        return f(minindex)
    else
        return false
    end
end
function _pointnearest(f, positions::Vector{<:Vector}, pos, accuracy)
    length(positions) > 0 || return false
    mindistance = Inf
    minindex = (0, 0)
    for i in eachindex(positions)
        for j in eachindex(positions[i])
            p = positions[i][j]
            distance = sqrt((p[1] - pos[1])^2 + (p[2] - pos[2])^2)
            if distance < mindistance
                mindistance = distance
                minindex = (i, j)
            end
        end
    end
    if (mindistance < accuracy) && (minindex != (0, 0))
        return f(minindex)
    else
        return false
    end
end

function _ison(line, point, accuracy)
    (x1, y1), (x2, y2) = line
    x = point[1]
    y = point[2]
    grad = (y2 - y1) / (x2 - x1)
    online = if grad in (Inf, -Inf, NaN, NaN32)
        x2 == x && inbounds((y1, y2), y)
    elseif grad == 0
        y2 == y && inbounds((x1, x2), x)
    else
        inbounds((y1, y2), y) && inbounds((x1, x2), x) || return false
        if grad > -1 && grad < 1
            line_y = round(grad * (x - x1) + y1)
            y in (line_y - accuracy)..(line_y + accuracy)
        else
            line_x = round((y - y1)/grad + x1)
            x in (line_x - accuracy)..(line_x + accuracy)
        end
    end
    return online
end

inbounds((x1, x2), x) = x >= min(x1, x2) && x <= max(x1, x2)

no_consume(args...) = Consume(false)
