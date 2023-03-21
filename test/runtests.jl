using TypeTreesIO
using AbstractTrees
using Test

AbstractTrees.children(node::TypeTreeNode) = (v = node.children; v === nothing ? () : v)
AbstractTrees.nodevalue(node::TypeTreeNode) = node.name

@testset "TypeTreesIO.jl" begin
    ttio = TypeTreeIO()
    print(ttio, typeof(view([1, 2, 3], 1:2)))
    @test sprint(ttio.tree) do io, tree
        print_tree(io, tree)
    end === """
    "SubArray"
    ├─ "Int64"
    ├─ " 1"
    ├─ " Vector"
    │  └─ "Int64"
    ├─ "UnitRange"
    │  └─ "Int64"
    └─ " true"
    """
end
