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
        print_tree(io, tree.body)
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
    @test sprint((io, node) -> print(IOContext(io, :type_maxdepth=>1), node), ttio.tree) == "SubArray{…}"
    @test sprint((io, node) -> print(IOContext(io, :type_maxdepth=>2), node), ttio.tree) == "SubArray{$Int, 1, Vector{…}, Tuple{…}, true}"
    @test sprint((io, node) -> print(IOContext(io, :type_maxdepth=>3), node), ttio.tree) == "SubArray{$Int, 1, Vector{$Int}, Tuple{UnitRange{…}}, true}"
    @test sprint((io, node) -> print(IOContext(io, :type_maxdepth=>4), node), ttio.tree) == "SubArray{$Int, 1, Vector{$Int}, Tuple{UnitRange{$Int}}, true}"
    @test sprint((io, node) -> print(IOContext(io, :type_maxwidth=>3), node), ttio.tree) == "SubArray{…}"
    @test sprint((io, node) -> print(IOContext(io, :type_maxwidth=>44), node), ttio.tree) == "SubArray{…}"
    @test sprint((io, node) -> print(IOContext(io, :type_maxwidth=>45), node), ttio.tree) == "SubArray{$Int, 1, Vector{…}, Tuple{…}, true}"
    @test sprint((io, node) -> print(IOContext(io, :type_maxwidth=>59), node), ttio.tree) == "SubArray{$Int, 1, Vector{…}, Tuple{…}, true}"
    @test sprint((io, node) -> print(IOContext(io, :type_maxwidth=>60), node), ttio.tree) == "SubArray{Int64, 1, Vector{Int64}, Tuple{UnitRange{…}}, true}"
    @test sprint((io, node) -> print(IOContext(io, :type_maxwidth=>100), node), ttio.tree) == "SubArray{$Int, 1, Vector{$Int}, Tuple{UnitRange{$Int}}, true}"

    ttio = TypeTreeIO()
    typ = Vector{V} where V<:AbstractVector{T} where T<:Real
    print(ttio, typ)
    @test sprint(print, ttio.tree) == sprint(print, typ)
    @test sprint((io, node) -> print(IOContext(io, :type_maxdepth=>1), node), ttio.tree) == "Vector{…} where {…}"
    @test sprint((io, node) -> print(IOContext(io, :type_maxdepth=>2), node), ttio.tree) == "Vector{V} where {T<:Real, V<:AbstractVector{…}}"
    @test sprint((io, node) -> print(IOContext(io, :type_maxdepth=>3), node), ttio.tree) == "Vector{V} where {T<:Real, V<:AbstractVector{T}}"
    @test sprint((io, node) -> print(IOContext(io, :type_maxwidth=>20), node), ttio.tree) == "Vector{…} where {…}"
    @test sprint((io, node) -> print(IOContext(io, :type_maxwidth=>46), node), ttio.tree) == "Vector{…} where {…}"
    @test sprint((io, node) -> print(IOContext(io, :type_maxwidth=>47), node), ttio.tree) == "Vector{V} where {T<:Real, V<:AbstractVector{T}}"

    ttio = TypeTreeIO()
    typ = Vector{T} where T<:Real
    print(ttio, typ)
    @test String(take!(ttio)) == sprint(print, typ)
    # Test whether it's reusable
    print(ttio, typ)
    @test String(take!(ttio)) == sprint(print, typ)
end
