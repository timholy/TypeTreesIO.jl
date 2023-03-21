module TypeTreesIO

export TypeTreeIO, TypeTreeNode

mutable struct TypeTreeNode
    name::String
    parent::Union{Nothing,TypeTreeNode}
    children::Union{Nothing,Vector{TypeTreeNode}}
end
TypeTreeNode(name::AbstractString="", parent=nothing) = TypeTreeNode(name, parent, nothing)

mutable struct TypeTreeIO <: IO    # TODO?: abstract type TextIO <: IO end for text-only printing
    io::IO
    tree::TypeTreeNode
    cursor::TypeTreeNode
end
function TypeTreeIO(io::IO=IOBuffer())
    root = TypeTreeNode()
    return TypeTreeIO(io, root, root)
end

Base.get(treeio::TypeTreeIO, key, default) = get(treeio.io, key, default)

getio(io::TypeTreeIO) = io.io
getio(ioctx::IOContext{TypeTreeIO}) = getio(ioctx.io)
getttio(io::TypeTreeIO) = io
getttio(io::IOContext{TypeTreeIO}) = io.io


function Base.write(treeio::TypeTreeIO, c::Char)
    curs = treeio.cursor
    if c == '{'
        if curs.children === nothing
            curs.children = TypeTreeNode[]
            curs.name = String(take!(getio(treeio)))
        else
            # We're dropping in depth
            newcurs = TypeTreeNode(String(take!(getio(treeio))), curs)
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
    else
        print(treeio.io, c)
    end
    return textwidth(c)
end

function Base.write(treeio::TypeTreeIO, s::Union{String,SubString{String}})
    n = 0
    for c in s
        n += write(treeio, c)
    end
    return n
end

writegeneric(treeio, x) = (write(getio(treeio), x); write(getttio(treeio), String(take!(getio(treeio)))))
printgeneric(treeio, x) = (print(getio(treeio), x); print(getttio(treeio), String(take!(getio(treeio)))))
 showgeneric(treeio, x) = (show(getio(treeio), x); print(getttio(treeio), String(take!(getio(treeio)))))

Base.write(treeio::IOContext{TypeTreeIO}, c::Char) = writegeneric(treeio, c)
Base.write(treeio::IOContext{TypeTreeIO}, s::Union{String,SubString{String}}) = writegeneric(treeio, s)

for IOT in (TypeTreeIO, IOContext{TypeTreeIO})
    @eval Base.write(treeio::$IOT, s::Symbol) = writegeneric(treeio, s)
    @eval Base.show(treeio::$IOT, c::AbstractChar) = showgeneric(treeio, c)
    @eval Base.show(treeio::$IOT, n::BigInt) = showgeneric(treeio, n)
    @eval Base.show(treeio::$IOT, n::Signed) = showgeneric(treeio, n)
end

end
