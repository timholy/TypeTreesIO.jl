module TypeTreesIOAbstractTrees

using TypeTreesIO, AbstractTrees

AbstractTrees.children(node::TypeTreesIO.TypeTreeNode) = (v = node.children; v === nothing ? [] : v)
AbstractTrees.children(node::TypeTreesIO.TypeVarTree) = vcat(children(node.lb), children(node.ub))
AbstractTrees.children(node::TypeTreesIO.UnionAllTree) = vcat(children(node.body), children(node.var))

AbstractTrees.nodevalue(node::TypeTreesIO.TypeTreeNode) = node.name
AbstractTrees.nodevalue(node::TypeTreesIO.UnionAllTree) = string(nodevalue(node.body), " where ", nodevalue(node.var))
function AbstractTrees.nodevalue(node::TypeTreesIO.TypeVarTree)
    body = nodevalue(node.body)
    if node.lb === nothing
        node.ub === nothing && return body
        return string(body, "<:", nodevalue(node.ub))
    end
    node.ub === nothing && return string(body, ">:", nodevalue(node.lb))
    return string(nodevalue(node.lb), "<:", body, "<:", nodevalue(node.ub))
end

__init__() = @info "loaded TypeTreesIOAbstractTrees"

end # module TypeTreesIOAbstractTrees
