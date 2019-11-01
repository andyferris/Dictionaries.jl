@testset "HashIndices" begin
    @test HashIndices() isa HashIndices{Any}

    h = HashIndices{Int64}()

    @test isinsertable(h)
    @test length(h) == 0
    @test keys(h) === h
    @test isempty(h)
    @test isequal(copy(h), h)
    @test_throws IndexError h[10]
    @test length(unset!(h, 10)) == 0
    io = IOBuffer(); print(io, h); @test String(take!(io)) == "0-element HashIndices{Int64}"
    @test_throws IndexError delete!(h, 10)

    insert!(h, 10)

    @test length(h) == 1
    @test keys(h) === h
    @test !isempty(h)
    @test isequal(copy(h), h)
    @test h[10] == 10
    @test_throws IndexError insert!(h, 10)
    @test length(set!(h, 10)) == 1
    @test_throws IndexError insert!(h, 10)
    io = IOBuffer(); print(io, h); @test String(take!(io)) == "1-element HashIndices{Int64}\n 10"
    @test !isequal(h, empty(h))
    @test isequal(h, copy(h))
    @test isempty(empty(h))

    delete!(h, 10)

    @test isequal(h, HashIndices{Int64}())

    for i = 2:2:1000
        insert!(h, i)
    end
    @test issetequal(h, HashIndices(2:2:1000))
    @test all(in(i, h) == iseven(i) for i in 2:1000)
    @test isempty(empty!(h))

    # TODO: token interface
end