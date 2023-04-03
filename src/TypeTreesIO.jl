module TypeTreesIO

export TypeTreeNode, typetree

struct TypeTreeNode
    name::Union{String,TypeVar}
    parent::Union{Nothing,TypeTreeNode}
    children::Union{Nothing,Vector{Any}}
end

const TypeNodeArg = Union{Union,DataType,TypeVar,Core.TypeofBottom}
const svnull = Core.svec()
const vnull = Any[]

childnode(@nospecialize(C), p) = isa(C, TypeNodeArg) ? TypeTreeNode(C, p) :
                                 isa(C, UnionAll) ? UnionAllTree(C, p) : TypeTreeNode(string(C), p, nothing)

function TypeTreeNode(@nospecialize(T::TypeNodeArg), parent=nothing)
    isa(T, TypeVar) && return TypeTreeNode(T, parent, nothing)
    Talias = Base.make_typealias(T)
    Talias !== nothing && return TypeTreeNode(Talias..., parent, T)
    isa(T, Core.TypeofBottom) && return TypeTreeNode("Union", parent, Any[])
    if isa(T, Union)
        node = TypeTreeNode("Union", parent, Any[])
        push!(node.children, childnode(T.a, node))
        push!(node.children, childnode(T.b, node))
        return node
    end
    T = T::DataType
    children = isempty(T.parameters) ? nothing : Any[]
    node = TypeTreeNode(string(T.name.name), parent, children)
    for p in T.parameters
        push!(node.children, childnode(p, node))
    end
    return node
end
function TypeTreeNode(gr::GlobalRef, p::Core.SimpleVector, parent, @nospecialize(T))
    name = sprint(Base.show_typealias, gr, T, svnull, vnull)
    node = TypeTreeNode(name, parent, isempty(p) ? nothing : Any[])
    if !isempty(p)
        for child in p
            push!(node.children, childnode(child, node))
        end
    end
    return node
end

struct TypeVarTree
    tv::TypeVar
    lb::Union{Nothing,TypeTreeNode}
    ub::Union{Nothing,TypeTreeNode}
end
function TypeVarTree(tv::TypeVar)
    bound(@nospecialize(b)) = b === Union{} ? nothing : TypeTreeNode(b)

    return TypeVarTree(tv, bound(tv.lb), bound(tv.ub))
end

struct UnionAllTree
    body::Union{TypeTreeNode, UnionAllTree}
    var::TypeVarTree
end
function UnionAllTree(T::UnionAll, parent=nothing)
    Talias = Base.make_typealias(T)
    Talias === nothing && return UnionAllTree(typetree(T.body, parent), TypeVarTree(T.var))
    return UnionAllTree(TypeTreeNode(Talias..., parent, T), TypeVarTree(T.var))
end

typetree(@nospecialize(T::Type), parent=nothing) = isa(T, UnionAll) ? UnionAllTree(T, parent) : TypeTreeNode(T, parent)

# mutable struct TypeTreeIO <: IO    # TODO?: abstract type TextIO <: IO end for text-only printing
#     io::Union{IOBuffer,IOContext{IOBuffer}}
#     tree::TypeTreeNode     # tree structure
#     cursor::TypeTreeNode   # current position in the tree
# end
# function TypeTreeIO(io=IOBuffer())
#     root = TypeTreeNode()
#     return TypeTreeIO(io, root, root)
# end

# ## IO interface

# Base.flush(::TypeTreeIO) = nothing
# if isdefined(Base, :closewrite)
#     Base.closewrite(::TypeTreeIO) = nothing
# end
# Base.iswritable(::TypeTreeIO) = true

# function Base.unsafe_write(io::TypeTreeIO, p::Ptr{UInt8}, nb::UInt)
#     str = String(unsafe_wrap(Array, p, (Int(nb),)))
#     for c in str
#         write(io, c)
#     end
#     return nb
# end

# Base.get(treeio::TypeTreeIO, key, default) = get(treeio.io, key, default)

# getio(io::TypeTreeIO) = io.io
# getio(ioctx::IOContext{TypeTreeIO}) = getio(ioctx.io)

# function Base.write(treeio::TypeTreeIO, c::Char)
#     curs = treeio.cursor
#     if c == '{'
#         str = String(take!(getio(treeio)))
#         if isempty(curs.name)
#             @assert curs.children === nothing
#             curs.children = TypeTreeNode[]
#             curs.name = str
#         else
#             # We're dropping in depth
#             newcurs = TypeTreeNode(str, curs)
#             if curs.children === nothing
#                 curs.children = TypeTreeNode[]
#             end
#             push!(curs.children, newcurs)
#             treeio.cursor = newcurs
#         end
#     elseif c ∈ (',', '}')
#         str = String(take!(getio(treeio)))
#         if !isempty(str)
#             if curs.children === nothing
#                 curs.children = TypeTreeNode[]
#             end
#             push!(curs.children, TypeTreeNode(str, curs))
#         else
#             p = curs.parent
#             if p !== nothing
#                 treeio.cursor = p
#             end
#         end
#     elseif c != ' '
#         print(treeio.io, c)
#     end
#     return textwidth(c)
# end


## Printing the tree with constraints on width and/or depth

const truncstr = "{…}"
const delims = ('{', '}')
const per_param = ", "

function Base.print(io::IO, node::TypeTreeNode; depth=nothing, maxdepth=typemax(Int), maxwidth=typemax(Int))
    if depth === nothing
        depth = choose_depth(node, maxdepth, maxwidth)
    end
    _print(io, node, 1, depth)
end
Base.println(io::IO, node::TypeTreeNode; kwargs...) = (print(io, node; kwargs...); print(io, '\n'))

function _print(io::IO, node::TypeTreeNode, thisdepth, maxdepth)
    print(io, node.name)
    childs = node.children
    if childs !== nothing
        if thisdepth >= maxdepth
            print(io, truncstr)
            return
        end
        print(io, delims[1])
        n = lastindex(childs)
        for (i, child) in pairs(childs)
            _print(io, child, thisdepth+1, maxdepth)
            i < n && print(io, per_param)
        end
        print(io, delims[end])
    end
end

function choose_depth(node::TypeTreeNode, maxdepth::Int, maxwidth::Int)
    wd, wtrunc = width_by_depth(node)
    wsum, depth = 0, 1
    while depth <= maxdepth && depth <= length(wd)
        wsum += wd[depth]
        if wsum + wtrunc[depth] > maxwidth
            return depth - 1
        end
        depth += 1
    end
    return depth - 1
end


"""
    width_by_depth(node) → wd, wtrunc

Compute the number of characters `wd[depth]` needed to print at each `depth` within the tree.
Also compute the number of additional characters `wtrunc[depth]` needed if one truncates the tree at `depth`.
"""
width_by_depth(node::TypeTreeNode) = width_by_depth!(Int[], Int[], node, 1)

function width_by_depth!(wd, wtrunc, node, depth)
    if depth > length(wd)
        push!(wd, 0)
        push!(wtrunc, 0)
    end
    wd[depth] += length(node.name)
    childs = node.children
    if childs !== nothing
        wd[depth] += length(delims)
        wtrunc[depth] += length(truncstr) - length(delims)
        for child in childs
            width_by_depth!(wd, wtrunc, child, depth+1)
        end
        wd[depth+1] += length(per_param) * (length(childs) - 1)
    end
    return wd, wtrunc
end

end
