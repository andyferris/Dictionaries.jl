@testset "find" begin
    i = Indices([1,2,3,4,5])

    @test issetequal(findall(iseven, i)::Indices, [2, 4])
    @test issetequal(findall(map(iseven, i))::Indices, [2, 4])
    @test issetequal(findall(isodd, i)::Indices, [1, 3, 5])

    @test findfirst(iseven, i) == 2
    @test findnext(iseven, i, 2) == 4
    @test findnext(iseven, i, 4) === nothing
    
    @test findlast(iseven, i) == 4
    @test findprev(iseven, i, 4) == 2
    @test findprev(iseven, i, 2) === nothing

    findmin(i) == (1, 1)
    findmax(i) == (5, 5)

    d = i .+ 1

    @test issetequal(findall(iseven, d)::Indices, [1, 3, 5])
    @test issetequal(findall(map(iseven, d))::Indices, [1, 3, 5])
    @test issetequal(findall(isodd, d)::Indices, [2, 4])

    @test findfirst(iseven, d) == 1
    @test findnext(iseven, d, 1) == 3
    @test findnext(iseven, d, 3) == 5
    @test findnext(iseven, d, 5) === nothing
    
    @test findlast(iseven, d) == 5
    @test findprev(iseven, d, 5) == 3
    @test findprev(iseven, d, 3) === 1
    @test findprev(iseven, d, 1) === nothing

    findmin(d) == (2, 1)
    findmax(d) == (6, 5)
end