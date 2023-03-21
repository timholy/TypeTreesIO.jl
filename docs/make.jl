using TypeTreeIO
using Documenter

DocMeta.setdocmeta!(TypeTreeIO, :DocTestSetup, :(using TypeTreeIO); recursive=true)

makedocs(;
    modules=[TypeTreeIO],
    authors="Tim Holy <tim.holy@gmail.com> and contributors",
    repo="https://github.com/timholy/TypeTreeIO.jl/blob/{commit}{path}#{line}",
    sitename="TypeTreeIO.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://timholy.github.io/TypeTreeIO.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/timholy/TypeTreeIO.jl",
    devbranch="main",
)
