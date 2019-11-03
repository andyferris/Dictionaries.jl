@testset "pairs()" begin
    h = HashIndices{Int64}([3,6,9])
    p = pairs(h)
    @test p isa AbstractDictionary{Int64, Pair{Int64, Int64}}
    @test p[3] === (3 => 3)
    @test p[6] === (6 => 6)
    @test p[9] === (9 => 9)
    @test length(p) === 3
end