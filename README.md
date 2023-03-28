# TypeTreesIO

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://timholy.github.io/TypeTreesIO.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://timholy.github.io/TypeTreesIO.jl/dev/)
[![Build Status](https://github.com/timholy/TypeTreesIO.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/timholy/TypeTreesIO.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/timholy/TypeTreesIO.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/timholy/TypeTreesIO.jl)

This is a prototype of an IO subtype that prints Julia's compound types as a tree.
This is intended to support omitting or folding types when printing stacktraces,
c.f. https://github.com/JuliaLang/julia/pull/48444#issuecomment-1410024782.

Demo:

```julia
using TypeTreesIO, AbstractTrees

AbstractTrees.children(node::TypeTreeNode) = (v = node.children; v === nothing ? () : v)
AbstractTrees.nodevalue(node::TypeTreeNode) = node.name

julia> ttio = TypeTreeIO();

julia> obj = view([1, 2, 3], 1:2);

julia> println(typeof(obj))
SubArray{Int64, 1, Vector{Int64}, Tuple{UnitRange{Int64}}, true}

julia> print(ttio, typeof(obj));

julia> print_tree(ttio.tree)
"SubArray"
├─ "Int64"
├─ "1"
├─ "Vector"
│  └─ "Int64"
├─ "Tuple"
│  └─ "UnitRange"
│     └─ "Int64"
└─ "true"

julia> println(stdout, ttio.tree; maxwidth=55)
SubArray{Int64, 1, Vector{…}, Tuple{…}, true}

julia> println(stdout, ttio.tree; maxwidth=60)
SubArray{Int64, 1, Vector{Int64}, Tuple{UnitRange{…}}, true}
```