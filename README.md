# TypeTreesIO

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://timholy.github.io/TypeTreesIO.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://timholy.github.io/TypeTreesIO.jl/dev/)
[![Build Status](https://github.com/timholy/TypeTreesIO.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/timholy/TypeTreesIO.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/timholy/TypeTreesIO.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/timholy/TypeTreesIO.jl)

This is a prototype of an IO subtype that prints Julia's parametric types as a tree.
This is intended to support omitting or folding types when printing stacktraces,
c.f. https://github.com/JuliaLang/julia/pull/48444#issuecomment-1410024782.

Demo:

```julia
using TypeTreesIO, AbstractTrees

AbstractTrees.children(node::TypeTreeNode) = (v = node.children; v === nothing ? () : v)
AbstractTrees.nodevalue(node::TypeTreeNode) = node.name

julia> obj = view([1, 2, 3], 1:2);    # a parametric type

julia> println(typeof(obj))           # what is that type?
SubArray{Int64, 1, Vector{Int64}, Tuple{UnitRange{Int64}}, true}

julia> ttio = TypeTreeIO();           # create the IO object that assembles a tree-of-strings structure

julia> print(ttio, typeof(obj));      # build the tree

julia> print_tree(ttio.tree)          # show the tree structure (from AbstractTrees)
"SubArray"
├─ "Int64"
├─ " 1"
├─ " Vector"
│  └─ "Int64"
├─ "UnitRange"
│  └─ "Int64"
└─ " true"
```
