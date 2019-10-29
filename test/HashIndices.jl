@testset "HashIndices" begin
    h = HashIndices{Int}()

    @test length(h) == 0
    @test keys(h) === h
    @test isempty(h)
    @test isequal(copy(h), h)
    @test h == HashIndices{Int}()
    @test_throws IndexError h[10]
    @test length(unset!(h, 10)) == 0
    io = IOBuffer(); print(io, h); @test String(take!(io)) == "0-element HashIndices{Int64}"
    @test_throws IndexError delete!(h, 10)

    insert!(h, 10)

    @test length(h) == 1
    @test keys(h) === h
    @test !isempty(h)
    @test isequal(copy(h), h)
    @test h[10] === 10
    @test_throws IndexError insert!(h, 10)
    @test length(set!(h, 10)) == 1
    @test_throws IndexError insert!(h, 10)
    io = IOBuffer(); print(io, h); @test String(take!(io)) == "1-element HashIndices{Int64}\n  10"
    @test h != HashIndices{Int}()
    @test h == copy(h)

    delete!(h, 10)

    @test isequal(h, HashIndices{Int}())
end