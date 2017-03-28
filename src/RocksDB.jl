module RocksDB

# The author(s) would like to acknowledge jerryzhenleicai and others who
# contributed to LevelDB.jl
# https://github.com/jerryzhenleicai/LevelDB.jl

depsfile = Pkg.dir("RocksDB","deps","deps.jl")
if isfile(depsfile)
    include(depsfile)
else
    error("RocksDB not properly installed. Please run Pkg.build(\"RocksDB\")")
end

# package code goes here
export open_db
export close_db
export create_write_batch
export batch_put
export write_batch
export db_put
export db_get
export db_delete
export db_range
export range_close

function open_db(file_path, create_if_missing)
    options = @threadcall( (:rocksdb_options_create, librocksdb), Ptr{Void}, ())
    if create_if_missing
        @threadcall( (:rocksdb_options_set_create_if_missing, librocksdb), Void,
              (Ptr{Void}, UInt8), options, 1)
    end
    err = Ptr{UInt8}[0]
    db = @threadcall( (:rocksdb_open, librocksdb), Ptr{Void},
               (Ptr{Void}, Ptr{UInt8}, Ptr{Ptr{UInt8}}) , options, file_path, err)

    if db == C_NULL
        error(unsafe_string(err[1]))
    end
    return db
end


function close_db(db)
    @threadcall( (:rocksdb_close, librocksdb), Void, (Ptr{Void},), db)
end

function db_put(db, key, value, val_len)
    options = @threadcall( (:rocksdb_writeoptions_create, librocksdb), Ptr{Void}, ())
    err = Ptr{UInt8}[0]
    @threadcall( (:rocksdb_put, librocksdb), Void,
          (Ptr{Void}, Ptr{Void}, Ptr{UInt8}, UInt, Ptr{UInt8}, UInt, Ptr{Ptr{UInt8}} ),
          db, options,key, length(key), value, val_len, err)
    if err[1] != C_NULL
        error(unsafe_string(err[1]))
    end
end

# return an UInt8 array obj
function db_get(db, key)
    # rocksdb_get will allocate the buffer for return value
    options = @threadcall( (:rocksdb_readoptions_create, librocksdb), Ptr{Void}, ())
    err = Ptr{UInt8}[0]
    val_len = Csize_t[0]
    value = @threadcall( (:rocksdb_get, librocksdb), Ptr{UInt8},
          (Ptr{Void}, Ptr{Void}, Ptr{UInt8}, UInt, Ptr{Csize_t},  Ptr{Ptr{UInt8}} ),
          db, options, key, length(key), val_len, err)
    if err[1] != C_NULL
        error(unsafe_string(err[1]))
    else
        s = unsafe_wrap(Array, value, (val_len[1],), true)
        s
    end
end

function db_delete(db, key)
    options = @threadcall( (:rocksdb_writeoptions_create, librocksdb), Ptr{Void}, ())
    err = Ptr{UInt8}[0]
    @threadcall( (:rocksdb_delete, librocksdb), Void,
          (Ptr{Void}, Ptr{Void}, Ptr{Void}, UInt, Ptr{Ptr{UInt8}} ),
          db, options, key, length(key), err)
    if err[1] != C_NULL
        error(unsafe_string(err[1]))
    end
end


function create_write_batch()
    batch = @threadcall( (:rocksdb_writebatch_create, librocksdb), Ptr{Void},())
    return batch
end



function batch_put(batch, key, value, val_len)
    @threadcall( (:rocksdb_writebatch_put, librocksdb), Void,
          (Ptr{UInt8}, Ptr{UInt8}, UInt, Ptr{UInt8}, UInt),
          batch, key, length(key), value, val_len)
end

function write_batch(db, batch)
    options = @threadcall( (:rocksdb_writeoptions_create, librocksdb), Ptr{Void}, ())
    err = Ptr{UInt8}[0]
    @threadcall( (:rocksdb_write, librocksdb), Void,
          (Ptr{Void}, Ptr{Void}, Ptr{Void},  Ptr{Ptr{UInt8}} ),
          db, options, batch, err)
    if err[1] != C_NULL
        error(unsafe_string(err[1]))
    end
end



function create_iter(db::Ptr{Void}, options::Ptr{Void})
  @threadcall( (:rocksdb_create_iterator, librocksdb), Ptr{Void},
              (Ptr{Void}, Ptr{Void}),
              db, options)
end

function iter_valid(it::Ptr{Void})
  @threadcall( (:rocksdb_iter_valid, librocksdb), UInt8,
    (Ptr{Void},),
    it) == 1
end

function iter_key(it::Ptr{Void})
  k_len = Csize_t[0]
  key = @threadcall( (:rocksdb_iter_key, librocksdb), Ptr{UInt8},
    (Ptr{Void}, Ptr{Csize_t}),
    it, k_len)
  unsafe_string(key, k_len[1])
end

function iter_value(it::Ptr{Void})
  v_len = Csize_t[0]
  value = @threadcall( (:rocksdb_iter_value, librocksdb), Ptr{UInt8},
    (Ptr{Void}, Ptr{Csize_t}),
    it, v_len)
    unsafe_wrap(Array, value, (v_len[1],), false)
end

function iter_seek(it::Ptr{Void}, key)
  @threadcall( (:rocksdb_iter_seek, librocksdb), Void,
    (Ptr{Void}, Ptr{UInt8}, UInt),
    it, key, length(key))
end

function iter_next(it::Ptr{Void})
  @threadcall( (:rocksdb_iter_next, librocksdb), Void,
    (Ptr{Void},),
    it)
end

type Range
  iter::Ptr{Void}
  options::Ptr{Void}
  key_start::String
  key_end::String
  destroyed::Bool
end

function db_range(db, key_start, key_end="\uffff")
  options = @threadcall( (:rocksdb_readoptions_create, librocksdb), Ptr{Void}, ())
  iter = create_iter(db, options)
  Range(iter, options, key_start, key_end, false)
end

function range_close(range::Range)
  if !range.destroyed
    range.destroyed = true
    @threadcall( (:rocksdb_iter_destroy, librocksdb), Void,
      (Ptr{Void},),
      range.iter)
    @threadcall( (:rocksdb_readoptions_destroy, librocksdb), Void,
      (Ptr{Void},),
      range.options)
  end
end

function Base.start(range::Range)
  iter_seek(range.iter, range.key_start)
end

function Base.done(range::Range, state=nothing)
  if range.destroyed
    return true
  end
  isdone = iter_valid(range.iter) ? iter_key(range.iter) > range.key_end : true
  if isdone
    range_close(range)
  end
  isdone
end

function Base.next(range::Range, state=nothing)
  k = iter_key(range.iter)
  v = iter_value(range.iter)
  iter_next(range.iter)
  ((k, v), nothing)
end


end # module
