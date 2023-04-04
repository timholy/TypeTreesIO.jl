using TypeTreesIO
using AbstractTrees
using Test

@testset "TypeTreesIO.jl" begin
    obj = view([1, 2, 3], 1:2)
    tt = typetree(typeof(obj))
    @test sprint(tt) do io, tree
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
    @test sprint(print, tt) == sprint(print, typeof(obj))
    @test sprint((io, node) -> print(io, node; maxdepth=1), tt) == "SubArray{…}"
    @test sprint((io, node) -> print(io, node; maxdepth=2), tt) == "SubArray{$Int, 1, Vector{…}, Tuple{…}, true}"
    @test sprint((io, node) -> print(io, node; maxdepth=3), tt) == "SubArray{$Int, 1, Vector{$Int}, Tuple{UnitRange{…}}, true}"
    @test sprint((io, node) -> print(io, node; maxdepth=4), tt) == "SubArray{$Int, 1, Vector{$Int}, Tuple{UnitRange{$Int}}, true}"
    @test sprint((io, node) -> print(io, node; maxwidth=3), tt) == "SubArray{…}"
    @test sprint((io, node) -> print(io, node; maxwidth=44), tt) == "SubArray{…}"
    @test sprint((io, node) -> print(io, node; maxwidth=45), tt) == "SubArray{$Int, 1, Vector{…}, Tuple{…}, true}"
    @test sprint((io, node) -> print(io, node; maxwidth=59), tt) == "SubArray{$Int, 1, Vector{…}, Tuple{…}, true}"
    @test sprint((io, node) -> print(io, node; maxwidth=60), tt) == "SubArray{Int64, 1, Vector{Int64}, Tuple{UnitRange{…}}, true}"
    @test sprint((io, node) -> print(io, node; maxwidth=100), tt) == "SubArray{$Int, 1, Vector{$Int}, Tuple{UnitRange{$Int}}, true}"

    typ = Vector{V} where V<:AbstractVector{T} where T<:Real
    tt = typetree(typ)
    @test sprint(print, tt) == sprint(print, typ)
    @test sprint((io, node) -> print(IOContext(io, :type_maxdepth=>1), node), tt) == "Vector{…} where {…}"
    @test sprint((io, node) -> print(IOContext(io, :type_maxdepth=>2), node), tt) == "Vector{V} where {T<:Real, V<:AbstractVector{…}}"
    @test sprint((io, node) -> print(IOContext(io, :type_maxdepth=>3), node), tt) == "Vector{V} where {T<:Real, V<:AbstractVector{T}}"
    @test sprint((io, node) -> print(IOContext(io, :type_maxwidth=>20), node), tt) == "Vector{…} where {…}"
    @test sprint((io, node) -> print(IOContext(io, :type_maxwidth=>46), node), tt) == "Vector{…} where {…}"
    @test sprint((io, node) -> print(IOContext(io, :type_maxwidth=>47), node), tt) == "Vector{V} where {T<:Real, V<:AbstractVector{T}}"

    typ = Vector{T} where T<:Real
    tt = typetree(typ)
    @test sprint(print, tt) == sprint(print, typ)
    @test sprint((io, node) -> print(IOContext(io, :type_maxdepth=>1), node), tt) == "Vector{…} where {…}"
    @test sprint((io, node) -> print(IOContext(io, :type_maxdepth=>2), node), tt) == sprint(print, typ)

    # Construction from Method signatures
    m = which(show, (IO, String))
    tt = typetree(m)
    @test sprint(print, tt) == strip(split(sprint(print, m), '@')[1])
end
