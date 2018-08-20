using Serialization

"""
    byte_array(x)

Serialize Julia type *x* such that it can be written to
a db or file
"""
function byte_array(x; endian_conv=false)
    iob = IOBuffer()
    seek(iob, 0)
    !endian_conv && serialize(iob, x)
    endian_conv && serialize(iob, big_endian(x))
    iob.data
end

"""
    array_to_type{T}(arr, ::Type{T})

Deserialize from Array{UInt8} back to Julia type.
"""
function array_to_type(arr, ::Type{T}; endian_conv=false) where T
    iob = IOBuffer(arr)
    seek(iob, 0)
    t = deserialize(iob)
    if ! isa(t, T)
        throw(ThimbleSerializeException("Could not deserialize to type"))
    end
    endian_conv && return native_endian(t)
    t
end

function array_to_type(arr; endian_conv=false)
    iob = IOBuffer(arr)
    seek(iob, 0)
    t = deserialize(iob)
    endian_conv && return native_endian(t)
    t
end

function big_endian(T)
    isa(T, Number) && return hton(T)
    isa(T, Tuple)  && return map(big_endian, T)
    T
end

function native_endian(T)
    isa(T, Number) && return ntoh(T)
    isa(T, Tuple)  && return map(native_endian, T)
    T
end

"""
Lexicographical comparison of byte vectors
"""
function Base.isless(x::Vector{UInt8}, y::Vector{UInt8})
    # TODO: use memcmp if lengths are equal
    for i = 1:length(x)
        x[i] < y[i] && return true
        x[i] > y[i] && return false
    end
    false
end
