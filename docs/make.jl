using TypeTreesIO
using Documenter

DocMeta.setdocmeta!(TypeTreesIO, :DocTestSetup, :(using TypeTreesIO); recursive=true)

makedocs(;
    modules=[TypeTreesIO],
    authors="Tim Holy <tim.holy@gmail.com> and contributors",
    repo="https://github.com/timholy/TypeTreesIO.jl/blob/{commit}{path}#{line}",
    sitename="TypeTreesIO.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://timholy.github.io/TypeTreesIO.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/timholy/TypeTreesIO.jl",
    devbranch="main",
)
