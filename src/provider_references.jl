# Find references to an identifier. Only works in file.
function process(r::JSONRPC.Request{Val{Symbol("textDocument/references")},ReferenceParams}, server)
    tdpp = r.params
    # uri = tdpp.textDocument.uri
    doc = server.documents[tdpp.textDocument.uri]
    offset = get_offset(doc, tdpp.position.line + 1, tdpp.position.character)
    
    y, Y, I, O, scope, modules, current_namespace = get_scope(doc, offset, server)
    locations = Location[]
    if y isa CSTParser.IDENTIFIER
        yid = CSTParser.get_id(y).val
        s_id = findlast(s -> s[1].id == CSTParser.get_id(y).val, scope)
        if s_id > 0
            V, LOC, uri = scope[s_id]
            locs = find_ref(doc.code.ast, V, LOC)
            for loc in locs
                push!(locations, Location(uri, Range(doc, loc)))
            end
        end
    end
    response = JSONRPC.Response(get(r.id), locations)
    send(response, server)
end

function JSONRPC.parse_params(::Type{Val{Symbol("textDocument/references")}}, params)
    return ReferenceParams(params)
end

function _find_ref(x::CSTParser.EXPR, V, LOC, offset, scope, refs)
    if CSTParser.no_iter(x)
        return x
    end
    for (i, a) in enumerate(x)
        if a isa CSTParser.EXPR
            if !isempty(a.defs)
                for v in a.defs
                    push!(scope, (v, offset + (1:a.span)))
                end
            end
            if CSTParser.contributes_scope(a)
                CSTParser.get_symbols(a, offset, scope)
            end
        end
        _find_ref(a, V, LOC, offset, copy(scope), refs)
        offset += a.span
    end
end

function _find_ref(x::Union{CSTParser.QUOTENODE,CSTParser.INSTANCE,CSTParser.ERROR}, V, LOC, offset, scope, refs) end

function _find_ref(x::CSTParser.IDENTIFIER, V, LOC, offset, scope, refs)
    if x.val == V.id
        scope_id = findlast(s -> s[1].id == V.id, scope)
        if scope_id > 0
            v, loc = scope[scope_id]
            if v == V && loc == LOC
                push!(refs, offset + (1:x.span))
            end
        end
    end
end

function find_ref(x::CSTParser.EXPR, V, LOC)
    offset = 0
    scope = Tuple{CSTParser.Variable,UnitRange}[]
    refs = UnitRange[]
    _find_ref(x, V, LOC, offset, scope, refs)
    return refs
end
