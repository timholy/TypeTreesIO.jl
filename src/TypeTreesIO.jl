module TypeTreesIO

export TypeTreeIO, TypeTreeNode

mutable struct TypeTreeNode
    name::String
    parent::Union{Nothing,TypeTreeNode}
    children::Union{Nothing,Vector{TypeTreeNode}}
end
TypeTreeNode(name::AbstractString="", parent=nothing) = TypeTreeNode(name, parent, nothing)

mutable struct TypeTreeBundle
    body::TypeTreeNode                  # DataType
    vars::Union{Nothing,TypeTreeNode}   # TypeVars
end
TypeTreeBundle(node::TypeTreeNode) = TypeTreeBundle(node, nothing)

mutable struct TypeTreeIO <: IO    # TODO?: abstract type TextIO <: IO end for text-only printing
    io::Union{IOBuffer,IOContext{IOBuffer}}
    tree::TypeTreeBundle
    cursor::TypeTreeNode   # current position in the tree
end
function TypeTreeIO(io=IOBuffer())
    root = TypeTreeNode()
    return TypeTreeIO(io, TypeTreeBundle(root), root)
end

## IO interface

Base.flush(::TypeTreeIO) = nothing
if isdefined(Base, :closewrite)
    Base.closewrite(::TypeTreeIO) = nothing
end
Base.iswritable(::TypeTreeIO) = true

function Base.unsafe_write(io::TypeTreeIO, p::Ptr{UInt8}, nb::UInt)
    str = String(unsafe_wrap(Array, p, (Int(nb),)))
    if startswith(str, " where ")
        @assert io.tree.vars === nothing
        io.cursor = io.tree.vars = TypeTreeNode(" where ")
        io.cursor.children = TypeTreeNode[]
        return nb
    end
    for c in str
        write(io, c)
    end
    return nb
end

Base.get(treeio::TypeTreeIO, key, default) = get(treeio.io, key, default)

getio(io::TypeTreeIO) = io.io
getio(ioctx::IOContext{TypeTreeIO}) = getio(ioctx.io)

function Base.write(treeio::TypeTreeIO, c::Char)
    curs = treeio.cursor
    if c == '{'
        str = String(take!(getio(treeio)))
        if isempty(curs.name)
            @assert curs.children === nothing
            curs.children = TypeTreeNode[]
            curs.name = str
        else
            # We're dropping in depth
            newcurs = TypeTreeNode(str, curs)
            if curs.children === nothing
                curs.children = TypeTreeNode[]
            end
            push!(curs.children, newcurs)
            treeio.cursor = newcurs
        end
    elseif c ∈ (',', '}')
        str = String(take!(getio(treeio)))
        if !isempty(str)
            if curs.children === nothing
                curs.children = TypeTreeNode[]
            end
            push!(curs.children, TypeTreeNode(str, curs))
        else
            p = curs.parent
            if p !== nothing
                treeio.cursor = p
            end
        end
    elseif c != ' '
        print(treeio.io, c)
    end
    return textwidth(c)
end


## Printing the tree with constraints on width and/or depth

const truncstr = "{…}"
const delims = ('{', '}')
const per_param = ", "

function Base.take!(io::TypeTreeIO)
    str = String(take!(io.io))
    if !isempty(str)
        curs = io.cursor
        if curs.children === nothing
            curs.children = TypeTreeNode[]
        end
        push!(curs.children, TypeTreeNode(str, curs))
    end
    str = sprint(show, io.tree)
    io.tree = TypeTreeBundle(TypeTreeNode())
    io.cursor = io.tree.body
    return codeunits(str)
end

function Base.show(io::IO, bundle::TypeTreeBundle)
    depth = get(io, :type_depth, nothing)::Union{Int,Nothing}
    if depth === nothing
        maxdepth = get(io, :type_maxdepth, typemax(Int))::Int
        maxwidth = get(io, :type_maxwidth, typemax(Int))::Int
        depth = choose_depth(bundle, maxdepth, maxwidth)
    end
    _print(io, bundle.body, 1, depth)
    vars = bundle.vars
    if vars !== nothing
        children = vars.children
        if children !== nothing && length(children) == 1
            vars = children[1]
            print(io, " where ")
        end
        _print(io, vars, 1, depth)
    end
end

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

function choose_depth(wd::Vector{Int}, wtrunc::Vector{Int}, maxdepth::Int, maxwidth::Int)
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
choose_depth(bundle::TypeTreeBundle, maxdepth::Int, maxwidth::Int) =
    choose_depth(width_by_depth(bundle)..., maxdepth, maxwidth)

"""
    width_by_depth(node) → wd, wtrunc

Compute the number of characters `wd[depth]` needed to print at each `depth` within the tree.
Also compute the number of additional characters `wtrunc[depth]` needed if one truncates the tree at `depth`.
"""
function width_by_depth(bundle::TypeTreeBundle)
    wd, wtrunc = Int[], Int[]
    width_by_depth!(wd, wtrunc, bundle.body, 1)
    if bundle.vars !== nothing
        width_by_depth!(wd, wtrunc, bundle.vars, 1)
    end
    return wd, wtrunc
end

function width_by_depth!(wd, wtrunc, node::TypeTreeNode, depth)
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
