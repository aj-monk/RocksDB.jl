using BinDeps
using Pkg

@BinDeps.setup

url = "https://github.com/ajaymendez/rocksdb/archive/c_checkpoint.zip"

librocksdb = library_dependency("librocksdb")

provides(Sources, URI(url), librocksdb, unpacked_dir="rocksdb-c_checkpoint")

builddir = BinDeps.builddir(librocksdb)
srcdir = joinpath(BinDeps.depsdir(librocksdb),"src", "rocksdb-c_checkpoint")
libdir = BinDeps.libdir(librocksdb)

if Sys.isapple()
    libfile = joinpath(libdir,librocksdb.name*".dylib")
    libname = "librocksdb.dylib"
elseif Sys.isunix()
    libfile = joinpath(libdir,librocksdb.name*".so")
    libname = "librocksdb.so"
end

provides(BuildProcess,
    (@build_steps begin
        GetSources(librocksdb)
        CreateDirectory(libdir)
        @build_steps begin
            ChangeDirectory(srcdir)
            FileRule(libfile, @build_steps begin
                     `make shared_lib`
                     `cp $(libname)  ../../usr/lib/`
            end)
        end
    end), librocksdb, os = :Unix)

@BinDeps.install Dict(:librocksdb => :librocksdb)
