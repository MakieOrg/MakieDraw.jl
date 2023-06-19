abstract type AbstractCanvasSelect <: Makie.Block end

"""
    CanvasSelect <: AbstractCanvasSelect 

A menu widget for selecting active canvases.

It will deactivate all non-selected canvases, and select the active one.

# Arguments
- `figure::Union{Figure,GridPosition}` a Figure or `GridPosition`.
- `ax::Axis`: the `Axis` the canvases are on.

# Keywords
- `layers`: Dict{Symbol,Orbservable{bool}

# Example

```julia
layers = Dict(
    :paint=>paint_canvas.active, 
    :point=>point_canvas.active, 
    :line=>line_canvas.active,
    :poly=>poly_canvas.active,
)

MakieDraw.CanvasSelect(figure[2, 1], axis; layers)
```
"""
struct CanvasSelect{L} <: AbstractCanvasSelect 
    layers::L
    menu::Menu
    axis::Axis
end
function CanvasSelect(m::Menu, ax::Axis; layers=Dict{Symbol,Observable{Bool}}())
    on(m.selection) do selected
        for (key, active) in layers 
            active[] = key == Symbol(selected)
            notify(active)
        end
    end
    CanvasSelect(layers, m, ax)
end
function CanvasSelect(fig::Union{Figure,GridPosition}, ax::Axis; layers=[])
    found_active = false
    default = "none"
    for (key, active) in pairs(layers)
        # Only the first active layer can stay active
        if !found_active && active[] 
            found_active = true
            default = string(key)
        else
            active[] = false
        end
    end
    options = map(string, collect(keys(layers)))
    m = Menu(fig; options, default)
    CanvasSelect(m, ax; layers)
end

layers(ls::AbstractCanvasSelect) = ls.layers

Base.push!(ls::AbstractCanvasSelect, x::Pair{Symbol,Observable{Bool}}) = push!(layers(ls), x)
Base.getindex(ls::AbstractCanvasSelect, key::Symbol) = layers(ls)[key]
Base.setindex!(ls::AbstractCanvasSelect, x::Observable{Bool}, key::Symbol) = layers(ls)[key] = x

function addtoswitchers!(c::GeometryCanvas)
    for x in c.figure.content
        # Find all AbstractCanvasSelect on this Axis
        if x isa AbstractCanvasSelect # && x.axis == ax
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
