module TypeTreesIO

export TypeTreeIO, TypeTreeNode

mutable struct TypeTreeNode
    name::String
    parent::Union{Nothing,TypeTreeNode}
    children::Union{Nothing,Vector{TypeTreeNode}}
end
TypeTreeNode(name::AbstractString="", parent=nothing) = TypeTreeNode(name, parent, nothing)

mutable struct TypeTreeIO <: IO    # TODO?: abstract type TextIO <: IO end for text-only printing
    io::Union{IOBuffer,IOContext{IOBuffer}}
    tree::TypeTreeNode     # tree structure
    cursor::TypeTreeNode   # current position in the tree
end
function TypeTreeIO(io=IOBuffer())
    root = TypeTreeNode()
    return TypeTreeIO(io, root, root)
end

## IO interface

Base.flush(::TypeTreeIO) = nothing
Base.closewrite(::TypeTreeIO) = nothing
Base.iswritable(::TypeTreeIO) = true

function Base.unsafe_write(io::TypeTreeIO, p::Ptr{UInt8}, nb::UInt)
    str = String(unsafe_wrap(Array, p, (Int(nb),)))
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
