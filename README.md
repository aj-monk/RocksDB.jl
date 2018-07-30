# RocksDB.jl

[![Build Status](https://travis-ci.org/ajaymendez/RocksDB.jl.svg?branch=master)](https://travis-ci.org/ajaymendez/RocksDB.jl)

[![Coverage Status](https://coveralls.io/repos/ajaymendez/RocksDB.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/ajaymendez/RocksDB.jl?branch=master)

[![codecov.io](http://codecov.io/github/ajaymendez/RocksDB.jl/coverage.svg?branch=master)](http://codecov.io/github/ajaymendez/RocksDB.jl?branch=master)

## RocksDB
[RocksDB](https://github.com/facebook/rocksdb)
is an [LSM](https://en.wikipedia.org/wiki/Log-structured_merge-tree)
based embedded key-value store inspired by Google's
[LevelDB](https://github.com/google/leveldb). The LSM design makes it
perform well on SSD devices.

## RocksDB.jl
RocksDB.jl is a Julia wrapper around librocksdb currently exposing only
a subset of functionality. If you want more functions from RocksDB please
submit a pull request or raise an issue.

RocksDB.jl calls into librocksdb using Julia's C calling interface.
Since IO from librocksdb does not use libuv's event driven mechanism
they could stall the Julia process. As a work around RocksDB.jl uses
the threadcall mechanism that schedules the call into librocksdb
on a separate thread.

## Usage
```julia
julia> using RocksDB

# Opening a db returns a handle
# Set the second parameter to false if you want the method to
# return an exception if the DB does not already exist.
julia> db = open_db("/tmp/test.db", true)

julia> db_put(db, "key1", "value1")

julia> val = db_get(db, "key1")
"value1"
```

**Key** and **Value** can be any Julia type. RocksDB.jl will serialize
them while writing and deserialize while reading.

```julia
julia> key = "key1"
"key1"

julia> value = rand(Int64)
1196320916215346617

julia> db_put(db, key, value)

julia> val = db_get(db, key)
1196320916215346617

julia> typeof(val)
Int64

# Compound types
julia> struct Foo
                 bar
                 baz::Int
                 qux::Float64
             end

julia> value = Foo("foo", 45, 4.33)
Foo("foo", 45, 4.33)

julia> db_put(db, "key2", value)

julia> val = db_get(db, "key2")
Foo("foo", 45, 4.33)

julia> typeof(val)
Foo
```

