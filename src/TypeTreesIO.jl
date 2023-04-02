module TypeTreesIO

export TypeTreeIO, TypeTreeNode

const delims = (('(', ')'), ('{', '}'))

mutable struct TypeTreeNode
    name::String
    parent::Union{Nothing,TypeTreeNode}
    delimidx::Int8          # 1 or 2 for delims[delimidx], 0 for not assigned
    children::Union{Nothing,Vector{TypeTreeNode}}
end
TypeTreeNode(name::AbstractString="", parent=nothing) = TypeTreeNode(name, parent, 0, nothing)

mutable struct TypeTreeBundle
    body::TypeTreeNode                  # DataType
    vars::Union{Nothing,TypeTreeNode}   # TypeVars
end
TypeTreeBundle(node::TypeTreeNode) = TypeTreeBundle(node, nothing)

"""
    TypeTreeIO() → io

Create an IO object to which you can print type objects or natural signatures.
Afterwards, `io.tree` will contain a tree representation of the printed type.

# Examples

```jldoctest
julia> io = TypeTreeIO();

julia> print(io, Tuple{Int,Float64});

julia> io.tree.body.name
"Tuple"

julia> io.tree.body.children[1].name
"$Int"

julia> String(take!(io))
"Tuple{$Int, Float64}"
```

# Extended help

In addition to printing a type directly to an `io::TypeTreeIO`, you can also
assemble it manually if you follow a few precautions:

    - any `where` statement must be printed as `print(io, " where ")` or
      `print(io, " where {")`. The `where` string argument may not have any
      additional characters. Note the bracketing spaces.

"""
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

function Base.flush(io::TypeTreeIO)
    str = String(take!(io.io))
    if !isempty(str)
        curs = io.cursor
        if curs.children === nothing
            curs.children = TypeTreeNode[]
        end
        push!(curs.children, TypeTreeNode(str, curs))
    end
    return
end
Base.iswritable(::TypeTreeIO) = true

function Base.unsafe_write(io::TypeTreeIO, p::Ptr{UInt8}, nb::UInt)
    str = String(unsafe_wrap(Array, p, (Int(nb),)))
    if startswith(str, " where ")
        @assert io.tree.vars === nothing
        io.cursor = io.tree.vars = TypeTreeNode(" where ")
        endswith(str, '{') && (io.cursor.delimidx = 2)
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
    if c ∈ ('{', '(')
        str = String(take!(getio(treeio)))
        if c == '(' && str == "typeof"
            # oops, we shouldn't have grabbed this, put it back
            print(getio(treeio), str, '(')
            return textwidth(c)
        end
        if isempty(curs.name)
            @assert curs.children === nothing
            curs.children = TypeTreeNode[]
            curs.name = str
            curs.delimidx = c == '(' ? 1 : 2
            else
            # We're dropping in depth
            newcurs = TypeTreeNode(str, curs)
            newcurs.delimidx = c == '(' ? 1 : 2
            if curs.children === nothing
                curs.children = TypeTreeNode[]
            end
            push!(curs.children, newcurs)
            treeio.cursor = newcurs
        end
    elseif c ∈ (',', '}', ')')
        str = String(take!(getio(treeio)))
        if !isempty(str)
            if c == ')' && startswith(str, "typeof(")
                # put it back
                print(getio(treeio), str, c)
                return textwidth(c)
            end
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

const truncchar = "…"
const per_param = ", "

function Base.take!(io::TypeTreeIO)
    flush(io)
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
        delimidx = node.delimidx
        iszero(delimidx) || print(io, delims[delimidx][1])
        if thisdepth >= maxdepth
            print(io, truncchar)
        else
            n = lastindex(childs)
            for (i, child) in pairs(childs)
                _print(io, child, thisdepth+1, maxdepth)
                i < n && print(io, per_param)
            end
        end
        iszero(delimidx) || print(io, delims[delimidx][end])
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
        delimidx = node.delimidx
        if !iszero(delimidx)
            wd[depth] += length(delims[node.delimidx])
        end
        wtrunc[depth] += length(truncchar)
        for child in childs
            width_by_depth!(wd, wtrunc, child, depth+1)
        end
        wd[depth+1] += length(per_param) * (length(childs) - 1)
    end
    return wd, wtrunc
end

end
