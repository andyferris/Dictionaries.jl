@testset "HashIndices" begin
    h = HashIndices{Int}()

    @test length(h) == 0
    @test keys(h) === h
    @test isempty(h)
    @test isequal(copy(h), h)
    @test_throws IndexError h[10]
    @test length(unset!(h, 10)) == 0

    insert!(h, 10)

    @test length(h) == 1
    @test keys(h) === h
    @test !isempty(h)
    @test isequal(copy(h), h)
    @test h[10] === 10
    @test_throws IndexError insert!(h, 10)
    @test length(set!(h, 10)) == 1

    delete!(h, 10)

    @test isequal(h, HashIndices{Int}())
end