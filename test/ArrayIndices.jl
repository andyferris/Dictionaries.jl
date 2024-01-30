@testset "ArrayIndices" begin
    @test ArrayIndices() isa ArrayIndices{Any}

    inds = ArrayIndices{Int64}()
    @test ArrayIndices{Int64, Vector{Int64}}() == inds

    @test isinsertable(inds)
    @test length(inds) == 0
    @test keys(inds) === inds
    @test isempty(inds)
    @test isequal(copy(inds), inds)
    @test_throws IndexError inds[10]
    @test length(unset!(inds, 10)) == 0
    io = IOBuffer(); print(io, inds); @test String(take!(io)) == "{}"
    io = IOBuffer(); show(io, MIME"text/plain"(), inds); @test String(take!(io)) == "0-element ArrayIndices{Int64, Vector{Int64}}"
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
    io = IOBuffer(); print(io, inds); @test String(take!(io)) == "{10}"
    io = IOBuffer(); show(io, MIME"text/plain"(), inds); @test String(take!(io)) == "1-element ArrayIndices{Int64, Vector{Int64}}\n 10"
    @test !isequal(inds, empty(inds))
    @test isequal(inds, copy(inds))
    @test isempty(empty(inds))

    delete!(inds, 10)

    @test isequal(inds, ArrayIndices{Int64}())
    @test union!(inds, Indices([1,2,3,4])) == Indices([1, 2, 3, 4])
    @test filter!(iseven, inds) == Indices([2, 4])

    empty!(inds)
    for i = 2:2:100
        insert!(inds, i)
    end
    @test issetequal(inds, Indices(2:2:100))
    @test all(in(i, inds) == iseven(i) for i in 2:100)
    @test isempty(empty!(inds))

    @testset "covert" begin
        i = Indices{Int32}([1,2,3])
        ai = ArrayIndices{Int32}([1,2,3])

        @test convert(AbstractIndices{Int32}, ai) === ai
        @test convert(AbstractIndices{Int64}, ai)::ArrayIndices{Int64} == i

        @test convert(ArrayIndices{Int32}, ai) === ai
        @test convert(ArrayIndices{Int64}, ai)::ArrayIndices{Int64} == i
        
        @test convert(ArrayIndices{Int32}, i)::ArrayIndices{Int32} == i
        @test convert(ArrayIndices{Int64}, i)::ArrayIndices{Int64} == i
    end

    @testset "rand" begin
        inds = ArrayIndices(["a", "b", "c", "d", "e"])
        for i = 1:100
            @test rand(inds) in ["a", "b", "c", "d", "e"]
        end
    end

    @testset "sort" begin
        inds = ArrayIndices([1, 5, 2])
        @test sort(inds)::ArrayIndices == ArrayIndices([1, 2, 5])
        @test sort(inds; rev=true)::ArrayIndices == ArrayIndices([5, 2, 1])

        @test sortperm(inds)::ArrayIndices == ArrayIndices([1, 2, 5])
        @test sortperm(inds; rev=true)::ArrayIndices == ArrayIndices([5, 2, 1])
        @test getindices(inds, sortperm(inds))::ArrayIndices == ArrayIndices([1, 2, 5])
        @test getindices(inds, sortperm(inds; rev=true))::ArrayIndices == ArrayIndices([5, 2, 1])

        indscopy = deepcopy(inds)
        sort!(indscopy)
        @test indscopy == ArrayIndices([1, 2, 5])

        indscopy = deepcopy(inds)
        sort!(indscopy; rev=true)
        @test indscopy == ArrayIndices([5, 2, 1])
    end
end