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

MakieDraw.CanvasSelect(figure[2, 1]; layers)
```
"""
struct CanvasSelect{L} <: AbstractCanvasSelect 
    layers::L
    menu::Menu
end
function CanvasSelect(m::Menu; layers=Dict{Symbol,Observable{Bool}}())
    on(m.selection) do selected
        for (key, active) in layers 
            active[] = key == Symbol(selected)
            notify(active)
        end
    end
    CanvasSelect(layers, m)
end
function CanvasSelect(fig::Union{Figure,GridPosition}; layers=Dict{Symbol,Observable{Bool}}())
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
    CanvasSelect(m; layers)
end

layers(ls::AbstractCanvasSelect) = ls.layers

Base.push!(ls::AbstractCanvasSelect, x::Pair{Symbol,Observable{Bool}}) = push!(layers(ls), x)
Base.getindex(ls::AbstractCanvasSelect, key::Symbol) = layers(ls)[key]
Base.setindex!(ls::AbstractCanvasSelect, x::Observable{Bool}, key::Symbol) = layers(ls)[key] = x
