using RocksDB
using Base.Test

# write your own tests here
db = RocksDB.open_db("/tmp/test.db", true)
a = Array{Int32}(1000)
for i in 1:1000
    a[i] = rand(Int32)
    RocksDB.db_put(db, string(i), a[i])
end

# Check if values are correct
for i in 1:1000
    val = RocksDB.db_get(db, string(i))
    @test val == a[i]
end
