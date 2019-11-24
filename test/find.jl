@testset "findall" begin
    i = HashIndices([1,2,3,4,5])

    @test issetequal(findall(iseven, i)::HashIndices, [2, 4])
    @test issetequal(findall(map(iseven, i))::HashIndices, [2, 4])
    @test issetequal(findall(isodd, i)::HashIndices, [1, 3, 5])

    d = i .+ 1

    @test issetequal(findall(iseven, d)::HashIndices, [1, 3, 5])
    @test issetequal(findall(map(iseven, d))::HashIndices, [1, 3, 5])
    @test issetequal(findall(isodd, d)::HashIndices, [2, 4])
end