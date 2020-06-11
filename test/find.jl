@testset "findall" begin
    i = Indices([1,2,3,4,5])

    @test issetequal(findall(iseven, i)::Indices, [2, 4])
    @test issetequal(findall(map(iseven, i))::Indices, [2, 4])
    @test issetequal(findall(isodd, i)::Indices, [1, 3, 5])

    d = i .+ 1

    @test issetequal(findall(iseven, d)::Indices, [1, 3, 5])
    @test issetequal(findall(map(iseven, d))::Indices, [1, 3, 5])
    @test issetequal(findall(isodd, d)::Indices, [2, 4])
end