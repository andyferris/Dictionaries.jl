@testset "FillDictionary" begin
    inds = Indices([2, 4, 6])
    dict = FillDictionary(inds, 100.0)

    @test keytype(dict) == Int
    @test eltype(dict) == Float64
    @test keys(dict) === inds
    @test dict[2] === 100.0
    @test_throws IndexError dict[3]
    @test dict == Dictionary([2, 4, 6], [100.0, 100.0, 100.0])
    @test dict == FillDictionary([2, 4, 6], 100.0)
    @test istokenizable(dict) == true
end