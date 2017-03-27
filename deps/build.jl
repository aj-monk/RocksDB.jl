using BinDeps

@BinDeps.setup

url = "https://github.com/facebook/rocksdb/archive/rocksdb-5.2.1.tar.gz"

librocksdb = library_dependency("librocksdb")

provides(Sources, URI(url), librocksdb, unpacked_dir="rocksdb-rocksdb-5.2.1")

builddir = BinDeps.builddir(librocksdb)
srcdir = joinpath(BinDeps.depsdir(librocksdb),"src", "rocksdb-rocksdb-5.2.1")
libdir = BinDeps.libdir(librocksdb)
libfile = joinpath(libdir,librocksdb.name*".so")

provides(BuildProcess,
    (@build_steps begin
        GetSources(librocksdb)
        CreateDirectory(libdir)
        @build_steps begin
            ChangeDirectory(srcdir)
            FileRule(libfile, @build_steps begin
                     `make shared_lib`
                     `cp librocksdb.so  ../..//usr/lib/librocksdb.so`
            end)
        end
    end), librocksdb, os = :Unix)

@BinDeps.install Dict(:librocksdb => :librocksdb)
