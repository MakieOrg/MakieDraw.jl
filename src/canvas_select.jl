abstract type AbstractCanvasSelect <: Makie.Block end

const LayerDict = Dict{Symbol,Observable{Bool}}

"""
    CanvasSelect <: AbstractCanvasSelect

    CanvasSelect(figure; [layers])

A menu widget for selecting active canvases.

It will deactivate all non-selected canvases, and select the active one.

# Arguments
- `figure::Union{Figure,GridPosition}` a Figure or `GridPosition`.

# Keywords
- `layers`: A `Dict{Symbol,Orbservable{Bool}}` where the Symbols are
    the names that will appear in the `Menu`, and the Observables are
    the initial

# Example

```julia
using MakieDraw, GLMakie

layers = Dict(
    :paint=>paint_canvas.active,
    :point=>point_canvas.active,
    :line=>line_canvas.active,
    :poly=>poly_canvas.active,
)

fig = Figure()
cs = CanvasSelect(fig[2, 1]; layers)
```
"""
struct CanvasSelect <: AbstractCanvasSelect
    layers::LayerDict
    menu::Menu
end
function CanvasSelect(m::Menu; layers::LayerDict=LayerDict())
    on(m.selection) do selected
        for (key, active) in layers
            active[] = key == Symbol(selected)
            notify(active)
        end
    end
    CanvasSelect(layers, m)
end
function CanvasSelect(fig::Union{Figure,GridPosition};
    layers::Dict{Symbol,<:Any}=LayerDict()
)
    bool_layers = _get_active_observables(layers)
    found_active = false
    default = "none"
    for (key, active) in pairs(bool_layers)
        # Only the first active layer can stay active
        if !found_active && active[]
            found_active = true
            default = string(key)
        else
            active[] = false
        end
    end
    options = map(string, collect(keys(bool_layers)))
    m = Menu(fig; options, default)
    CanvasSelect(m; layers=bool_layers)
end

layers(cs::AbstractCanvasSelect) = cs.layers
menu(cs::AbstractCanvasSelect) = cs.menu
menuoptions(cs::AbstractCanvasSelect) = menu(cs).options
menuselection(cs::AbstractCanvasSelect) = menu(cs).selection

function Base.push!(cs::AbstractCanvasSelect, p::Pair{Symbol,<:AbstractCanvas})
    push!(cs, p[1] => p[2].active)
end
function Base.push!(cs::AbstractCanvasSelect, p::Pair{Symbol,Observable{Bool}})
    k, v = p
    opts = menuoptions(cs)
    ls = layers(cs)
    if haskey(layers(cs), k)
        if ls[k][]
            # Turn of the canvas before we remove it
            ls[k][] = false
        else
            # Turn off the new canvas before we add it
            v[] = false
            notify(v)
        end
        push!(ls, p)
    else
        v[] = false
        notify(v)
        push!(ls, p)
        push!(opts[], string(k))
    end
    notify(opts)
    return v
end
Base.getindex(cs::AbstractCanvasSelect, k::Symbol) = layers(cs)[k]
function Base.setindex!(cs::AbstractCanvasSelect, c::AbstractCanvas, k::Symbol)
    cs[k] = c.active
    return c
end
function Base.setindex!(cs::AbstractCanvasSelect, v::Observable{Bool}, k::Symbol)
    opts = menuoptions(cs)
    ls = layers(cs)
    if haskey(layers(cs), k)
        # Turn of the canvas before we remove it
        ls[k][] = false
        notify(ls[k])
    else
        v[] = false
        notify(v)
    end
    ls[k] = v
    if !(k in opts[])
        push!(opts[], string(k))
    end
    notify(opts)
    return v
end

# Get the `active` observables from any `AbstractCanvas` passed in the Dict.
function _get_active_observables(layers::Dict)
    bool_layers = LayerDict()
    for (k, v) in pairs(layers)
        active_obs = if v isa AbstractCanvas
            v.active
        elseif v isa Observable{Bool}
            v
        else
            throw(ArgumentError("$(typeof(v)) not an allowed layer type: pass an `Observable{Bool}` or any `AbstractCanvas`"))
        end
        bool_layers[k] = active_obs
    end

    return bool_layers
end
