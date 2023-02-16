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

function addtoswitchers!(fig, ax::Axis, c::GeometryCanvas)
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
