using TypeTreesIO
using AbstractTrees
using Test

AbstractTrees.children(node::TypeTreeNode) = (v = node.children; v === nothing ? () : v)
AbstractTrees.nodevalue(node::TypeTreeNode) = node.name

@testset "TypeTreesIO.jl" begin
    ttio = TypeTreeIO()
    obj = view([1, 2, 3], 1:2)
    print(ttio, typeof(obj))
    @test sprint(ttio.tree) do io, tree
        print_tree(io, tree)
    end === """
    "SubArray"
    ├─ "$Int"
    ├─ "1"
    ├─ "Vector"
    │  └─ "$Int"
    ├─ "Tuple"
    │  └─ "UnitRange"
    │     └─ "$Int"
    └─ "true"
    """
    @test sprint(print, ttio.tree) == sprint(print, typeof(obj))
    @test sprint((io, node) -> print(io, node; maxdepth=1), ttio.tree) == "SubArray{…}"
    @test sprint((io, node) -> print(io, node; maxdepth=2), ttio.tree) == "SubArray{$Int, 1, Vector{…}, Tuple{…}, true}"
    @test sprint((io, node) -> print(io, node; maxdepth=3), ttio.tree) == "SubArray{$Int, 1, Vector{$Int}, Tuple{UnitRange{…}}, true}"
    @test sprint((io, node) -> print(io, node; maxdepth=4), ttio.tree) == "SubArray{$Int, 1, Vector{$Int}, Tuple{UnitRange{$Int}}, true}"
    @test sprint((io, node) -> print(io, node; maxwidth=3), ttio.tree) == "SubArray{…}"
    @test sprint((io, node) -> print(io, node; maxwidth=44), ttio.tree) == "SubArray{…}"
    @test sprint((io, node) -> print(io, node; maxwidth=45), ttio.tree) == "SubArray{$Int, 1, Vector{…}, Tuple{…}, true}"
    @test sprint((io, node) -> print(io, node; maxwidth=59), ttio.tree) == "SubArray{$Int, 1, Vector{…}, Tuple{…}, true}"
    @test sprint((io, node) -> print(io, node; maxwidth=60), ttio.tree) == "SubArray{Int64, 1, Vector{Int64}, Tuple{UnitRange{…}}, true}"
    @test sprint((io, node) -> print(io, node; maxwidth=100), ttio.tree) == "SubArray{$Int, 1, Vector{$Int}, Tuple{UnitRange{$Int}}, true}"
end
