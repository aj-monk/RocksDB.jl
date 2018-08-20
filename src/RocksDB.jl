__precompile__()
module RocksDB

# The author(s) would like to acknowledge jerryzhenleicai and others who
# contributed to LevelDB.jl
# https://github.com/jerryzhenleicai/LevelDB.jl

using Pkg

#=
depsfile = joinpath(pathof(RocksDB), "deps", "deps.jl")
if isfile(depsfile)
    include(depsfile)
else
    error("RocksDB not properly installed. Please run Pkg.build(\"RocksDB\")")
end
=#

const depsfile = joinpath(dirname(@__FILE__), "..", "deps", "deps.jl")
if isfile(depsfile)
    include(depsfile)
else
    error("RocksDB not properly installed. Please run Pkg.build(\"RocksDB\") then restart Julia.")
end

export open_db, close_db
export create_write_batch, batch_put, write_batch
export db_put, db_get, db_delete
export db_range, range_close, db_delete_range, db_compact_range
export db_snap_key_range, db_create_snapshot, db_release_snapshot
export db_backup_open, db_backup_create, db_backup_close
export db_backup_purge, db_backup_restore
export db_create_checkpoint

struct RocksDBException <: Exception
    msg::String
end

include("serialize.jl")
include("interface.jl")
end # module
