function check_err(err)
    err[1] != C_NULL && throw(RocksDBException(error(unsafe_string(err[1]))))
    nothing
end

function open_db(file_path, create_if_missing)
    options = @threadcall( (:rocksdb_options_create, librocksdb), Ptr{Nothing}, ())
    if create_if_missing
        @threadcall( (:rocksdb_options_set_create_if_missing, librocksdb), Nothing,
              (Ptr{Nothing}, UInt8), options, 1)
    end
    err = Ptr{UInt8}[0]
    db = @threadcall( (:rocksdb_open, librocksdb), Ptr{Nothing},
               (Ptr{Nothing}, Ptr{UInt8}, Ptr{Ptr{UInt8}}) , options, file_path, err)

    @threadcall( (:rocksdb_options_destroy, librocksdb), Nothing, (Ptr{Nothing},), options)

    db == C_NULL && check_err(err)

    return db
end

function close_db(db)
    @threadcall( (:rocksdb_close, librocksdb), Nothing, (Ptr{Nothing},), db)
end

function db_put(db, key, value; raw=false)
    options = @threadcall( (:rocksdb_writeoptions_create, librocksdb), Ptr{Nothing}, ())
    k = byte_array(key, endian_conv=true)
    v = raw ? value : byte_array(value)
    err = Ptr{UInt8}[0]
    @threadcall( (:rocksdb_put, librocksdb), Nothing,
          (Ptr{Nothing}, Ptr{Nothing}, Ptr{UInt8}, UInt, Ptr{UInt8}, UInt, Ptr{Ptr{UInt8}} ),
          db, options,k, length(k), v, length(v), err)
    check_err(err)
end

function db_put_sync(db, key, value; raw=false)
    options = @threadcall( (:rocksdb_writeoptions_create, librocksdb), Ptr{Nothing}, ())
    @threadcall( (:rocksdb_writeoptions_set_sync, librocksdb), Nothing,
                 (Ptr{Nothing}, UInt8), options, 1)
    k = byte_array(key, endian_conv=true)
    v = raw ? value : byte_array(value)
    err = Ptr{UInt8}[0]
    @threadcall( (:rocksdb_put, librocksdb), Nothing,
                 (Ptr{Nothing}, Ptr{Nothing}, Ptr{UInt8}, UInt, Ptr{UInt8}, UInt, Ptr{Ptr{UInt8}} ),
                 db, options,k, length(k), v, length(v), err)
    check_err(err)
end

function db_get(db, key; raw=false)
    # rocksdb_get will allocate the buffer for return value
    options = @threadcall( (:rocksdb_readoptions_create, librocksdb), Ptr{Nothing}, ())
    err = Ptr{UInt8}[0]
    val_len = Csize_t[0]
    k = byte_array(key, endian_conv=true)
    value = @threadcall( (:rocksdb_get, librocksdb), Ptr{UInt8},
          (Ptr{Nothing}, Ptr{Nothing}, Ptr{UInt8}, UInt, Ptr{Csize_t},  Ptr{Ptr{UInt8}} ),
          db, options, k, length(k), val_len, err)
    check_err(err)

    s = unsafe_wrap(Array, value, (val_len[1],), own=true)
    return val_len[1] == 0 ? nothing : (raw ? s : array_to_type(s))
end

function db_delete(db, key)
    options = @threadcall( (:rocksdb_writeoptions_create, librocksdb), Ptr{Nothing}, ())
    err = Ptr{UInt8}[0]
    k = byte_array(key, endian_conv=true)
    @threadcall( (:rocksdb_delete, librocksdb), Nothing,
          (Ptr{Nothing}, Ptr{Nothing}, Ptr{Nothing}, UInt, Ptr{Ptr{UInt8}} ),
          db, options, k, length(k), err)
    check_err(err)
end

function create_write_batch()
    batch = @threadcall( (:rocksdb_writebatch_create, librocksdb), Ptr{Nothing},())
    return batch
end

function batch_put(batch, key, value; raw=false)
    k = byte_array(key, endian_conv=true)
    v = raw ? value : byte_array(value)
    @threadcall( (:rocksdb_writebatch_put, librocksdb), Nothing,
          (Ptr{UInt8}, Ptr{UInt8}, UInt, Ptr{UInt8}, UInt),
          batch, k, length(k), v, length(v))
end

function write_batch(db, batch)
    options = @threadcall( (:rocksdb_writeoptions_create, librocksdb), Ptr{Nothing}, ())
    err = Ptr{UInt8}[0]
    @threadcall( (:rocksdb_write, librocksdb), Nothing,
          (Ptr{Nothing}, Ptr{Nothing}, Ptr{Nothing},  Ptr{Ptr{UInt8}} ),
          db, options, batch, err)
    check_err(err)
end

function create_iter(db::Ptr{Nothing}, options::Ptr{Nothing})
  @threadcall( (:rocksdb_create_iterator, librocksdb), Ptr{Nothing},
              (Ptr{Nothing}, Ptr{Nothing}),
              db, options)
end

function iter_valid(it::Ptr{Nothing})
  @threadcall( (:rocksdb_iter_valid, librocksdb), UInt8,
    (Ptr{Nothing},),
    it) == 1
end

function iter_key(it::Ptr{Nothing})
  k_len = Csize_t[0]
  key = @threadcall( (:rocksdb_iter_key, librocksdb), Ptr{UInt8},
    (Ptr{Nothing}, Ptr{Csize_t}),
    it, k_len)
  r = unsafe_wrap(Array, key, (k_len[1],), own=false)
end

function iter_value(it::Ptr{Nothing})
  v_len = Csize_t[0]
  value = @threadcall( (:rocksdb_iter_value, librocksdb), Ptr{UInt8},
    (Ptr{Nothing}, Ptr{Csize_t}),
    it, v_len)
  r = unsafe_wrap(Array, value, (v_len[1],), own=false)
end

function iter_seek(it::Ptr{Nothing}, key)
  @threadcall( (:rocksdb_iter_seek, librocksdb), Nothing,
    (Ptr{Nothing}, Ptr{UInt8}, UInt),
    it, key, length(key))
end

function iter_next(it::Ptr{Nothing})
  @threadcall( (:rocksdb_iter_next, librocksdb), Nothing,
    (Ptr{Nothing},),
    it)
end

abstract type AbstractRange end

mutable struct Range <: AbstractRange
    iter::Ptr{Nothing}    # RocksDB iterator
    options::Ptr{Nothing} # RocksDB options
    key_start::Vector{UInt8}  # Starting key
    key_end::Vector{UInt8}    # Ending key
    raw::Bool          # Read the value without de-serializing to julia type
    destroyed::Bool    # RocksDB iterator and options are destroyed
end

mutable struct KeyRange <: AbstractRange
    iter::Ptr{Nothing}
    options::Ptr{Nothing}
    key_start::Vector{UInt8}
    key_end::Vector{UInt8}
    destroyed::Bool
end

function db_range(db, key_start, key_end; raw=false)
    options = @threadcall( (:rocksdb_readoptions_create, librocksdb), Ptr{Nothing}, ())
    ks = byte_array(key_start, endian_conv=true)
    ke = byte_array(key_end, endian_conv=true)
    iter = create_iter(db, options)
    Range(iter, options, ks, ke, raw, false)
end

function range_close(range::AbstractRange)
    if !range.destroyed
        range.destroyed = true
        @threadcall( (:rocksdb_iter_destroy, librocksdb), Nothing,
                     (Ptr{Nothing},),
                     range.iter)
        @threadcall( (:rocksdb_readoptions_destroy, librocksdb), Nothing,
                     (Ptr{Nothing},),
                     range.options)
    end
end


function Base.iterate(range::AbstractRange)
    iter_seek(range.iter, range.key_start)
    iterate(range, nothing)
end

function Base.iterate(range::Range, state)
    r = iter_key(range.iter)
    k = length(r) == 0 ? nothing : array_to_type(r, endian_conv=true)
    r = iter_value(range.iter)
    v = length(r) == 0 ? nothing : (range.raw ? r : array_to_type(r))
    iter_next(range.iter)
    (k == nothing || k == array_to_type(range.key_end, endian_conv=true)) && return nothing
    ((k, v), nothing)
end

#=
function Base.start(range::AbstractRange)
    iter_seek(range.iter, range.key_start)
end

function Base.done(range::AbstractRange, state=nothing)
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
    r = iter_key(range.iter)
    k = length(r) == 0 ? nothing : array_to_type(r, endian_conv=true)
    r = iter_value(range.iter)
    v = length(r) == 0 ? nothing : (range.raw ? r : array_to_type(r))
    iter_next(range.iter)
    ((k, v), nothing)
end
=#

"""
    db_key_range(db, key_start, key_end)
A range that returns only keys, no values
"""
function db_key_range(db, key_start, key_end)
    options = @threadcall( (:rocksdb_readoptions_create, librocksdb), Ptr{Nothing}, ())
    ks = byte_array(key_start, endian_conv=true)
    ke = byte_array(key_end, endian_conv=true)
    iter = create_iter(db, options)
    KeyRange(iter, options, ks, ke, false)
end

function Base.next(range::KeyRange, state=nothing)
    r = iter_key(range.iter)
    k = length(r) == 0 ? nothing : array_to_type(r, endian_conv=true)
    iter_next(range.iter)
    (k, nothing)
end

"""
    db_snap_key_range(db, snap, key_start, key_end)
A range that returns only keys, no values
"""
function db_snap_key_range(db, snap, key_start, key_end)
    options = @threadcall( (:rocksdb_readoptions_create, librocksdb), Ptr{Nothing}, ())
    @threadcall( (:rocksdb_readoptions_set_snapshot, librocksdb), Nothing,
                 (Ptr{Nothing}, Ptr{Nothing}), options, snap)
    ks = byte_array(key_start, endian_conv=true)
    ke = byte_array(key_end, endian_conv=true)
    iter = create_iter(db, options)
    Range(iter, options, ks, ke, false)
end

"""
    db_compact_range(db, start_key, end_key)
Compact (free storage) in the given range start_key:end_key
Caution: This call will delete ranges in snapshots.
"""
function db_compact_range(db, skey, ekey)
    err = Ptr{UInt8}[0]
    sk = byte_array(skey, endian_conv=true)
    ek = byte_array(ekey, endian_conv=true)
    # Delete files in range to free up storage
    @threadcall( (:rocksdb_delete_file_in_range, librocksdb), Nothing,
                 (Ptr{Nothing}, Ptr{UInt8}, UInt, Ptr{UInt8}, UInt, Ptr{Ptr{UInt8}} ),
                 db, sk, length(sk), ek, length(ek), err)
    check_err(err)
    # Compact range to free up storage
    @threadcall( (:rocksdb_compact_range, librocksdb), Nothing,
                 (Ptr{Nothing}, Ptr{UInt8}, UInt, Ptr{UInt8}, UInt),
                 db, sk, length(sk), ek, length(ek))
end

"""
    db_delete_range(db, start_key, limit_key)
Delete keys in the range start_key:limit_key including start key and limit_key.
"""
function db_delete_range(db, start_key, limit_key)
    sk = byte_array(start_key, endian_conv=true)
    lk = byte_array(limit_key, endian_conv=true)
    for k in RocksDB.db_key_range(db, sk, lk)
        db_delete(db, k)
    end
    #compact_range(db, start_key, limit_key)
end

"""
    db_backup_open(backup_dir)
Returns an instance of backup engine which backs up in *backup_dir*.
"""
function db_backup_open(backup_dir)
    options = @threadcall( (:rocksdb_options_create, librocksdb), Ptr{Nothing}, ())
    err = Ptr{UInt8}[0]
    be = @threadcall( (:rocksdb_backup_engine_open, librocksdb), Ptr{Nothing},
                 (Ptr{Nothing}, Ptr{UInt8}, Ptr{Ptr{UInt8}}),
                 options, backup_dir, err)
    check_err(err)
    return be
end

"""
    db_backup_create(be, db)
Given the backup engine *be*, backs up the database *db* in the directory
opened by *be*.
"""
function db_backup_create(be, db)
    err = Ptr{UInt8}[0]
    @threadcall( (:rocksdb_backup_engine_create_new_backup, librocksdb), Nothing,
                 (Ptr{Nothing}, Ptr{Nothing}, Ptr{Ptr{UInt8}}),
                 be, db, err)
    check_err(err)
end

function db_backup_close(be)
    @threadcall( (:rocksdb_backup_engine_close, librocksdb), Nothing, (Ptr{Nothing},), be)
end

"""
    db_backup_purge(be, num_to_keep)
Keep *num_to_keep* back ups and purge the older ones.
"""
function db_backup_purge(be, num_to_keep)
    err = Ptr{UInt8}[0]
    @threadcall( (:rocksdb_backup_engine_purge_old_backups, librocksdb), Nothing,
                 (Ptr{Nothing}, UInt, Ptr{Ptr{UInt8}}),
                 be, num_to_keep, err)
    check_err(err)
end

"""
    db_backup_restore(be, db_dir)
Restore the latest backup in *be* to *db_dir*. The restored db can be opened
using *db_open*.
"""
function db_backup_restore(be, db_dir)
    options = @threadcall( (:rocksdb_restore_options_create, librocksdb), Ptr{Nothing}, ())
    err = Ptr{UInt8}[0]
    @threadcall( (:rocksdb_backup_engine_restore_db_from_latest_backup, librocksdb), Nothing,
                 (Ptr{Nothing}, Ptr{UInt8}, Ptr{UInt8}, Ptr{Nothing}, Ptr{Ptr{UInt8}}),
                 be, db_dir, db_dir, options, err)
    check_err(err)
    @threadcall( (:rocksdb_restore_options_destroy, librocksdb), Nothing,
                 (Ptr{Nothing},), options)
end

"""
    db_create_snapshot(db)
For the given *db* return a snapshot object *snap* which can be iterated on with
*db_snap_key_range*. Snapshots are lightweight in RocksDB due to its LSM origins.
Snapshots are transient because they cannot be recovered after restarting the
process.
"""
function db_create_snapshot(db)
    @threadcall( (:rocksdb_create_snapshot, librocksdb), Ptr{Nothing},
                 (Ptr{Nothing},), db)
end

"""
    db_release_snapshot(db, snap)
Release storage for the given snapshot *snap* associated with *db*.
"""
function db_release_snapshot(db, snap)
    @threadcall( (:rocksdb_create_snapshot, librocksdb), Nothing,
                 (Ptr{Nothing}, Ptr{Nothing}), db, snap)
end

"""
    db_create_checkpoint(db, path)
For the given *db* create a checkpoint in *path*. *path* must be an absolute
path to a directory where the checkpoint will be created. The last component of
*path* should not exist when making this call. Checkpoints are persistent.
They can be opened for reads and writes, as a regular db would, by passing
the *path*.

Checkpoints are more lightweight than backups. While backups copy the contents
of the database checkpoints create links to the original files. Checkpoints are
deleted by deleting the directory.
"""
function db_create_checkpoint(db, path)
    err = Ptr{UInt8}[0]
    @threadcall( (:rocksdb_create_checkpoint, librocksdb), Nothing,
                 (Ptr{Nothing}, Ptr{UInt8}, Ptr{Ptr{UInt8}}),
                 db, path, err)
    check_err(err)
end
