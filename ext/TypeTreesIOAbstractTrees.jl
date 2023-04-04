module TypeTreesIOAbstractTrees

using TypeTreesIO, AbstractTrees

AbstractTrees.children(node::TypeTreesIO.TypeTreeNode) = (v = node.children; v === nothing ? [] : v)
function AbstractTrees.children(node::TypeTreesIO.TypeVarTree)
    if node.lb === nothing
        node.ub === nothing && return []
        return children(node.ub)
    end
    node.ub === nothing && return children(node.lb)
    return vcat(children(node.lb), children(node.ub))
end
AbstractTrees.children(node::TypeTreesIO.UnionAllTree) = vcat(children(node.body), children(node.var))

AbstractTrees.nodevalue(node::TypeTreesIO.TypeTreeNode) = node.name
AbstractTrees.nodevalue(node::TypeTreesIO.UnionAllTree) = string(nodevalue(node.body), " where ") #, nodevalue(node.var))
function AbstractTrees.nodevalue(node::TypeTreesIO.TypeVarTree)
    body = string(node.tv.name)
    if node.lb === nothing
        node.ub === nothing && return body
        return string(body, "<:", nodevalue(node.ub))
    end
    node.ub === nothing && return string(body, ">:", nodevalue(node.lb))
    return string(nodevalue(node.lb), "<:", body, "<:", nodevalue(node.ub))
end

end # module TypeTreesIOAbstractTrees
