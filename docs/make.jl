using MakieDraw
using Documenter

DocMeta.setdocmeta!(MakieDraw, :DocTestSetup, :(using MakieDraw); recursive=true)

makedocs(;
    modules=[MakieDraw],
    authors="Rafael Schouten <rafaelschouten@gmail.com>",
    repo="https://github.com/MakieOrg/MakieDraw.jl/blob/{commit}{path}#{line}",
    sitename="MakieDraw.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://MakieOrg.github.io/MakieDraw.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/MakieOrg/MakieDraw.jl",
    push_preview=true,
)
