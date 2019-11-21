################################################################################
# PMap
# A persistent map type that maps integers to values; it works for hash's,
# objectid's, or for making sparse vectors.

const PMAP_KEY_T = typejoin(typeof(hash(nothing)), typeof(objectid(nothing)))
_keysplit(k::PMAP_KEY_T) = (Int(k & 0b11111) + 1, k >> 5)

# We need a type for PMap entries--they can be empty entries (not yet assigned),
# singleton entries (a key and a value), or an antire sub-map:
abstract type PMapNode{T} end
struct PMap{T} <: AbstractDict{PMAP_KEY_T, T}
    _n::Int
    _data::PVec32{PMapNode{T}}
end
struct PMapEmptyNode{T} <: PMapNode{T} end
struct PMapSubmapNode{T} <: PMapNode{T}
    _map::PMap{T}
end
struct PMapSingleNode{T} <: PMapNode{T}
    _key::PMAP_KEY_T
    _val::T
end
PMapSingleNode{T}(p::Pair{PMAP_KEY_T,S}) where {T,S<:T} = PMapSingleNode{T}(p[1], p[2])
# A few handy methods for the above:
Base.length(::PMapEmptyNode{T}) where {T} = 0
Base.length(::PMapSingleNode{T}) where {T} = 1
Base.length(n::PMapSubmapNode{T}) where {T} = length(n._map)


# make sure pmaps have a hash and equality operator that is appropriate
_iseq(t::PMap{T}, s::AbstractDict{K,S}, eqfn::Function) where {T,K<:Integer,S} = begin
    (length(t) == length(s)) || return false
    for kv in s
        v = get(t, kv, t)
        (v === t) && return false
        eqfn(v, kv[2]) || return false
    end
    return true
end
isequiv(t::PMap{T}, s::AbstractDict{K,S}) where {T,K<:Integer,S} = _iseq(t, s, isequiv)
isequiv(s::AbstractDict{K,S}, t::PMap{T}) where {T,K<:Integer,S} = _iseq(t, s, isequiv)
Base.isequal(t::PMap{T}, s::AbstractDict{K,S}) where {T,K<:Integer,S} = _iseq(t, s, isequal)
Base.isequal(s::AbstractDict{K,S}, t::PMap{T}) where {T,K<:Integer,S} = _iseq(t, s, isequal)
equivhash(t::PMap{T}) where {T} = let h = objectid(T)
    for (k,v) in t
        h += equivhash(v) * (k + 31)
    end
    return h
end

# How we print pmaps:
_print_pmap(io::IO, u::PMap{T}, head::String) where {T} = begin
    print(io, "$(head)[")
    n = length(u)
    if n < 50
        for (ii,kv) in enumerate(u)
            if   ii > 1 print(io, ", $(repr(kv))")
            else        print(io, "$(repr(kv))")
            end
        end
    else
        for (ii,kv) in enumerate(u)
            if     ii > 50 break
            elseif ii > 1  print(io, ", $(repr(kv))")
            else           print(io, "$(repr(kv))")
            end
        end
        print(io, " ...")
    end
    print(io, "]")
end
Base.show(io::IO, ::MIME"text/plain", pv::PMap{T}) where {T} =
    _print_pmap(io, pv, "PMap")

Base.length(m::PMap) = m._n
Base.get(m::PMap{T}, k::PMAP_KEY_T, df) where {T} = begin
    let (k1,k2) = _keysplit(k), u = m._data[k1]
        if isa(u, PMapEmptyNode{T})
            return df
        elseif isa(u, PMapSubmapNode{T})
            return get(u._map, k2, df)
        elseif k != u._key
            return df
        else
            return u._val
        end
    end
end
Base.in(kv::Pair{PMAP_KEY_T,T}, m::PMap{T}) where {T} = begin
    let k = kv[1], v = kv[2], u = get(m, k, m)
        (u === m) && return false
        return u == v
    end
end
Base.iterate(m::PMap{T}) where {T} = begin
    for (k,v) in enumerate(m._data)
        if isa(v, PMapEmptyNode{T})
            continue
        elseif isa(v, PMapSubmapNode{T})
            let (x,st) = iterate(v._map), kk = (x[1] << 5) | (k - 1)
                return (Pair{PMAP_KEY_T,T}(kk, x[2]), (k, st...))
            end
        else
            return (Pair{PMAP_KEY_T,T}(v._key, v._val), (k+1,))
        end
    end
end
Base.iterate(m::PMap{T}, st::Tuple) where {T} = begin
    if length(st) == 0
        return iterate(m)
    else
        let k1 = st[1]
            for k in k1:32
                let u = m._data[k]
                    if isa(u, PMapEmptyNode{T})
                        continue
                    elseif isa(u, PMapSubmapNode{T})
                        let it = (k == k1 ? iterate(u._map, st[2:end]) : iterate(u._map))
                            if it === nothing
                                continue
                            else
                                let kv = it[1], kk = (kv[1] << 5) | (k - 1)
                                    return (Pair{PMAP_KEY_T,T}(kk, kv[2]), (k, it[2]...))
                                end
                            end
                        end
                    else
                        return (Pair{PMAP_KEY_T,T}(u._key, u._val), (k+1,))
                    end
                end
            end
        end
    end
    return nothing
end
assoc(u::PMapEmptyNode{T}, k::PMAP_KEY_T, v::S) where {T, S<:T} = PMapSingleNode{T}(k, v)
assoc(u::PMapSingleNode{T}, k::PMAP_KEY_T, v::S) where {T, S<:T} = begin
    if u._key != k
        u = assoc(assoc(PMap{T}(), 1 + (u._key >> 5), u._val), k >> 5, v)
        return PMapSubmapNode{T}(u)
    elseif u._val === v
        return u
    else
        return PMapSingleNode{T}(k, v)
    end
end
assoc(u::PMapSubmapNode{T}, k::PMAP_KEY_T, v::S) where {T, S<:T} = begin
    let nu = length(u._map), uu = assoc(u._map, k >> 5, v)
        return (uu === u._map ? u : PMapSubmapNode{T}(uu))
    end
end
assoc(m::PMap{T}, k::PMAP_KEY_T, v::S) where {T, S<:T} = begin
    let k1 = 1 + (k & 0x1f), u = m._data[k1], nu = length(u), uu = assoc(u, k, v)
        if uu === u
            return m
        else
            return PMap{T}(m._n - nu + length(uu), assoc(m._data, k1, uu))
        end
    end
end
dissoc(u::PMapEmptyNode{T}, k::PMAP_KEY_T) where {T} = u
dissoc(u::PMapSingleNode{T}, k::PMAP_KEY_T) where {T} = (u._key == k ? PMapEmptyNode{T}() : u)
dissoc(u::PMapSubmapNode{T}, k::PMAP_KEY_T) where {T} = let uu = dissoc(u._map, k >> 5)
    if uu === u._map
        return u
    elseif length(uu) == 0
        return PMapEmptyNode{T}()
    elseif length(uu) == 1
        let kv = first(uu), kk = (kv[1] << 5) | (k & 0x1f)
            return PMapSingleNode{T}(kk, kv[2])
        end
    else
        return PMapSubmapNode{T}(uu)
    end
end
dissoc(m::PMap{T}, k::PMAP_KEY_T) where {T} = begin
    let k1 = 1 + (k & 0x1f), u = m._data[k1], nu = length(u), uu = dissoc(u, k)
        if uu === u
            return m
        else
            return PMap{T}(m._n - nu + length(uu), assoc(m._data, k1, uu))
        end
    end
end


################################################################################
# Transients

mutable struct TMap{T} <: AbstractDict{PMAP_KEY_T, T}
    _n::Int
    _data::Array{PMapNode{T}, 1}
end
struct TMapSubmapNode{T} <: PMapNode{T}
    _map::TMap{T}
end
TMap{T}() where {T} = let q = PMapEmptyNode{T}()
    return TMap{T}(0, PMapNode{T}[q for i in 1:32])
end
TMap{T}(m::PMap{T}) where {T} = TMap{T}(m._n, PMapNode{T}[u for u in m._data])
Base.length(t::TMap) = t._n
Base.get(m::TMap{T}, k::PMAP_KEY_T, df) where {T} = begin
    let (k1,k2) = _keysplit(k), u = m._data[k1]
        if isa(u, PMapEmptyNode{T})
            return df
        elseif isa(u, PMapSubmapNode{T})
            return get(u._map, k2, df)
        elseif isa(u, TMapSubmapNode{T})
            return get(u._map, k2, df)
        elseif k != u._key
            return df
        else
            return u._val
        end
    end
end
Base.in(m::TMap{T}, kv::Pair{PMAP_KEY_T,T}) where {T} = begin
    let k = kv[1], v = kv[2], u = get(m, k, m)
        (u === m) && return false
        return u == v
    end
end
Base.iterate(m::TMap{T}) where {T} = begin
    for (k,v) in enumerate(m._data)
        if isa(v, PMapEmptyNode{T})
            continue
        elseif isa(v, Union{PMapSubmapNode{T}, TMapSubmapNode{T}})
            let (x,st) = iterate(v._map), kk = (x[1] << 5) | (k - 1)
                return (Pair{PMAP_KEY_T,T}(kk, x[2]), (k, st...))
            end
        else
            return (Pair{PMAP_KEY_T,T}(v._key, v._val), (k+1,))
        end
    end
end
Base.iterate(m::TMap{T}, st::Tuple) where {T} = begin
    if length(st) == 0
        return iterate(m)
    else
        let k1 = st[1]
            for k in k1:32
                let u = m._data[k]
                    if isa(u, PMapEmptyNode{T})
                        continue
                    elseif isa(u, Union{PMapSubmapNode{T}, TMapSubmapNode{T}})
                        let it = (k == k1 ? iterate(u._map, st[2:end]) : iterate(u._map))
                            if it === nothing
                                continue
                            else
                                let kv = it[1], kk = (kv[1] << 5) | (k - 1)
                                    return (Pair{PMAP_KEY_T,T}(kk, kv[2]), (k, it[2]...))
                                end
                            end
                        end
                    else
                        return (Pair{PMAP_KEY_T,T}(u._key, u._val), (k+1,))
                    end
                end
            end
        end
    end
    return nothing
end
Base.setindex!(m::TMap{T}, v::S, k::PMAP_KEY_T) where {T, S<:T} = begin
    let (k1,k2) = _keysplit(k), u = m._data[k1], n0
        if isa(u, PMapEmptyNode{T})
            m._data[k1] = PMapSingleNode{T}(k, v)
            m._n += 1
            return v
        elseif isa(u, PMapSingleNode{T})
            if k != u._key
                let tm = TMap{T}()
                    tm[u._key >> 5] = u._val
                    m._data[k1] = u = TMapSubmapNode{T}(tm)
                end
            elseif v == u._val
                return u._val
            else
                m._data[k1] = PMapSingleNode{T}(k, v)
                return v
            end
        elseif isa(u, PMapSubmapNode{T})
            m._data[k1] = u = TMapSubmapNode{T}(TMap{T}(u._map))
        end
        # if we reach this point, u is the (possibly) new submap and v needs adding
        n0 = u._map._n
        u._map[k2] = v
        m._n += (u._map._n - n0)
        return v
    end
end
Base.delete!(m::TMap{T}, k::PMAP_KEY_T) where {T} = begin
    let (k1,k2) = _keysplit(k), u = m._data[k1], n0
        if isa(u, PMapEmptyNode{T})
            return m
        elseif isa(u, PMapSingleNode{T})
            if u._key == k
                m._data[k1] = PMapEmptyNode{T}()
                m._n -= 1
            end 
            return m
        elseif isa(u, PMapSubmapNode{T})
            m._data[k1] = u = TMapSubmapNode{T}(TMap{T}(u._map))
        end
        n0 = u._map._n
        delete!(u._map, k2)
        m._n -= (n0 - u._map._n)
        return m
    end
end

thaw(m::PMap{T}) where {T} = TMap{T}(m)
freeze(m::TMap{T}) where {T} = let ar = PMapNode{T}[freeze(u) for u in m._data]
    PMap{T}(m._n, PVec32{PMapNode{T}}(ar))
end
freeze(m::TMapSubmapNode{T}) where {T} = PMapSubmapNode{T}(freeze(m._map))

# Constructors
PMap{T}(m::TMap{T}) where {T} = freeze(m)
PMap(kvs::Vararg{Union{Tuple{PMAP_KEY_T,S},Pair{PMAP_KEY_T,S}}}) where {S} = begin
    let m0 = TMap{S}(), m = m0
        for kv in kvs
            m[kv[1]] = kv[2]
        end
        return PMap{T}(m)
    end
end
PMap{T}(kvs::Vararg{Union{Tuple{PMAP_KEY_T,S},Pair{PMAP_KEY_T,S}}}) where {T,S<:T} = begin
    let m = TMap{T}()
        for kv in kvs
            m[kv[1]] = kv[2]
        end
        return PMap{T}(m)
    end
end
PMap{T}() where {T} = let e = PMapEmptyNode{T}()
    return PMap{T}(0, PVec32{PMapNode{T}}(NTuple{32, PMapNode{T}}(PMapNode{T}[e for ii in 1:32])))
end

