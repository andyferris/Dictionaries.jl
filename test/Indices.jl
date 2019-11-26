@testset "Indices" begin
    inds = Indices{Int}((1,3,5))

    @test length(inds) == 3
    @test 3 ∈ inds
    @test 4 ∉ inds
    @test all(isodd, inds)
    @test keys(inds) === inds
end

@testset "VectorIndices" begin
    @test HashIndices() isa HashIndices{Any}

    inds = Indices{Int64}()

    @test isinsertable(inds)
    @test length(inds) == 0
    @test keys(inds) === inds
    @test isempty(inds)
    @test isequal(copy(inds), inds)
    @test_throws IndexError inds[10]
    @test length(unset!(inds, 10)) == 0
    io = IOBuffer(); print(io, inds); @test String(take!(io)) == "0-element Indices{Int64,Array{Int64,1}}"
    @test_throws IndexError delete!(inds, 10)

    insert!(inds, 10)

    @test length(inds) == 1
    @test keys(inds) === inds
    @test !isempty(inds)
    @test isequal(copy(inds), inds)
    @test inds[10] == 10
    @test_throws IndexError insert!(inds, 10)
    @test length(set!(inds, 10)) == 1
    @test_throws IndexError insert!(inds, 10)
    io = IOBuffer(); print(io, inds); @test String(take!(io)) == "1-element Indices{Int64,Array{Int64,1}}\n 10"
    @test !isequal(inds, empty(inds))
    @test isequal(inds, copy(inds))
    @test isempty(empty(inds))

    delete!(inds, 10)

    @test isequal(inds, Indices{Int64}())

    for i = 2:2:100
        insert!(inds, i)
    end
    @test issetequal(inds, HashIndices(2:2:100))
    @test all(in(i, inds) == iseven(i) for i in 2:100)
    @test isempty(empty!(inds))
end