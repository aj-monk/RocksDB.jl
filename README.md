# RocksDB.jl

[![Build Status](https://travis-ci.org/aj-monk/RocksDB.jl.svg?branch=master)](https://travis-ci.org/aj-monk/RocksDB.jl)

[![Coverage Status](https://coveralls.io/repos/aj-monk/RocksDB.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/aj-monk/RocksDB.jl?branch=master)

[![codecov.io](http://codecov.io/github/aj-monk/RocksDB.jl/coverage.svg?branch=master)](http://codecov.io/github/aj-monk/RocksDB.jl?branch=master)

## RocksDB
[RocksDB](https://github.com/facebook/rocksdb)
is an [LSM](https://en.wikipedia.org/wiki/Log-structured_merge-tree)
based embedded key-value store inspired by Google's
[LevelDB](https://github.com/google/leveldb). The LSM design makes it
perform well on SSD devices. RocksDB also has many features that LevelDB
doesn't, like snapshots and checkpoints.

## RocksDB.jl
RocksDB.jl is a Julia wrapper around librocksdb currently exposing only
a subset of functionality. If you want more functions from RocksDB please
submit a pull request or raise an issue.

RocksDB.jl calls into librocksdb using Julia's C calling interface.
Since IO from librocksdb does not use libuv's event driven mechanism
they could stall the Julia process. As a work around RocksDB.jl uses
the threadcall mechanism that schedules the call into librocksdb
on a separate thread.

## Basic Usage
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
Call db_delete() to delete a key and it's corresponding value.

```julia
julia> db_get(db, "key1")
1196320916215346617

julia> db_delete(db, "key1")

```

If **key** does not exist then db_get() returns a **Void**.
```julia
julia> val = db_get(db, "key1")

julia> typeof(val)
Void

julia> if val == nothing
           println("Nothing stored at key1")
       end
Nothing stored at key1

```

In order to read a range of keys from the db call db_range() which
returns an iterator for (key, value) tuples.

```julia
julia> for i in 1:100
           db_put(db, string(i), i)
       end

julia> r = db_range(db, "3", "15")
RocksDB.Range(Ptr{Void} @0x00007fd1240016e0, Ptr{Void} @0x00007fd1280008c0, UInt8[0x21, 0x01, 0x33, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  …  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], UInt8[0x21, 0x02, 0x31, 0x35, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  …  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], false, false)

julia> for (key, value) in r
           println("key: ", key, " value: ", value)
       end
key: 3 value: 3
key: 4 value: 4
key: 5 value: 5
key: 6 value: 6
key: 7 value: 7
key: 8 value: 8
key: 9 value: 9
key: 10 value: 10
key: 11 value: 11
key: 12 value: 12
key: 13 value: 13
key: 14 value: 14
key: 15 value: 15
```


## Transactions
RocksDB supports batch writes where every key/value that is put in a batch
is atomically committed.
```julia
julia> batch = create_write_batch()
Ptr{Void} @0x00007f923c0318f0

julia> batch_put(batch, "one", 1)

julia> batch_put(batch, "two", 2)

julia> batch_put(batch, "three", 3)

julia> write_batch(db, batch)  # Commits the batch
```
## Checkpoints
Checkpoints are persistent snapshots of the entire db. They are typically
used to take backups or to keep track of db state.

Call sb_create_checkpoint(db, path) to create a checkpoint in *path*.
*path* must be an absolute
path to a directory where the checkpoint will be created. The last component of
*path* should not exist when making this call. Checkpoints are persistent.
They can be opened for reads and writes, as a regular db would, by passing
the *path*.
```julia
julia> db_create_checkpoint(db, "/tmp/chkpt1")

julia> chkpt1 = open_db("/tmp/chkpt1", false)
Ptr{Void} @0x00007fd114012fc0

julia> db_get(chkpt1, "one")
1

julia> db_get(chkpt1, "two")
2
```
