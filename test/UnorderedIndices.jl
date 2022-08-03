@testset "UnorderedIndices" begin
    @test UnorderedIndices() isa UnorderedIndices{Any}
    @test_throws IndexError UnorderedIndices([1, 1])
    @test @inferred(UnorderedIndices(2*x for x in 1:10))::UnorderedIndices == UnorderedIndices(2:2:20)

    h = UnorderedIndices{Int64}()

    @test isinsertable(h)
    @test length(h) == 0
    @test keys(h) === h
    @test h == h
    @test h == copy(h)
    @test isempty(h)
    @test issetequal(copy(h), h)
    @test_throws IndexError h[10]
    @test length(unset!(h, 10)) == 0
    io = IOBuffer(); print(io, h); @test String(take!(io)) == "{}"
    io = IOBuffer(); show(io, MIME"text/plain"(), h); @test String(take!(io)) == "0-element UnorderedIndices{Int64}"
    @test_throws IndexError delete!(h, 10)

    insert!(h, 10.0)

    @test length(h) == 1
    @test keys(h) === h
    @test unique(h) === h
    @test h == h
    @test h == copy(h)
    @test !isempty(h)
    @test issetequal(copy(h), h)
    @test h[10.0] == 10
    @test_throws IndexError insert!(h, 10)
    @test length(set!(h, 10)) == 1
    @test_throws IndexError insert!(h, 10)
    io = IOBuffer(); print(io, h); @test String(take!(io)) == "{10}"
    io = IOBuffer(); show(io, MIME"text/plain"(), h); @test String(take!(io)) == "1-element UnorderedIndices{Int64}\n 10"
    @test !isequal(h, empty(h))
    @test issetequal(h, copy(h))
    @test isempty(empty(h))

    delete!(h, 10.0)

    @test issetequal(h, UnorderedIndices{Int64}())

    for i = 2:2:1000
        insert!(h, i)
    end
    @test issetequal(h, UnorderedIndices(2:2:1000))
    @test all(in(i, h) == iseven(i) for i in 2:1000)
    @test isempty(empty!(h))

    # set
    @test length(set!(h, 1)) == 1
    @test length(set!(h, 2, 2)) == 2
    @test length(set!(h, 3.0, 3.0)) == 3
    @test_throws ErrorException set!(h, 4, 5)

    @testset "Comparison" begin
        i1 = UnorderedIndices([1,2,3])
        i2 = UnorderedIndices([1,2])

        @test issetequal(i1, i1)
        @test !issetequal(i1, i2)
        @test !issetequal(i2, i1)
        @test issetequal(i2, i2)
    end

    @testset "Adapated from Dict tests from Base" begin
        h = UnorderedIndices{Int}()
        N = 10000

        for i in 1:N
            insert!(h, i)
        end
        for i in 1:N
            @test i in h
        end
        for i in 1:2:N
            delete!(h, i)
        end
        for i in 1:N
            @test (i in h) == iseven(i)
        end
        for i in 1:2:N
            insert!(h, i)
        end
        for i in 1:N
            @test i in h
        end
        for i in 1:N
            delete!(h, i)
        end
        @test isempty(h)
        insert!(h, 77)
        @test 77 in h
        for i in 1:N
            set!(h, i)
        end
        for i in 1:N
            @test i in h
        end
        for i in 1:2:N
            delete!(h, i)
        end
        for i in 1:N
            @test (i in h) == iseven(i)
        end
        for i in N+1:2N
            insert!(h, i)
        end
        for i in 1:2N
            @test (i in h) == (i > N || iseven(i))
        end
    end

    @testset "set logic" begin
        i1 = UnorderedIndices([1,2])
        i2 = UnorderedIndices([2,3])
        i3 = UnorderedIndices([3,4])
        i4 = UnorderedIndices([2])

        s1 = [4,5]

        @test !issetequal(i1, i2)
        @test !(i1 ⊆ i2)
        @test i4 ⊆ i1

        if VERSION < v"1.5-"
            @test !disjoint(i1, i2)
            @test disjoint(i1, i3)
        else
            @test !isdisjoint(i1, i2)
            @test isdisjoint(i1, i3)
        end

        @test issetequal(union(i1, i2), UnorderedIndices([1,2,3]))
        @test issetequal(union(i2, i1), UnorderedIndices([2,3,1]))
        @test issetequal(union(i1, i3), UnorderedIndices([1,2,3,4]))
        @test issetequal(union(i1, s1), UnorderedIndices([1,2,4,5]))

        @test issetequal(intersect(i1, i2), UnorderedIndices([2]))
        @test issetequal(intersect(i1, i3), UnorderedIndices([]))
        @test issetequal(intersect(i3, s1), UnorderedIndices([4]))

        @test issetequal(setdiff(i1, i2), UnorderedIndices([1]))
        @test issetequal(setdiff(i1, i3), UnorderedIndices([1, 2]))
        @test issetequal(setdiff(i3, s1), UnorderedIndices([3]))

        @test issetequal(symdiff(i1, i2), UnorderedIndices([1, 3]))
        @test issetequal(symdiff(i1, i3), UnorderedIndices([1, 2, 3, 4]))
        @test issetequal(symdiff(i3, s1), UnorderedIndices([3, 5]))
    end

    @testset "covert" begin
        i = UnorderedIndices{Int32}([1,2,3])
        ai = ArrayIndices{Int32}([1,2,3])

        @test convert(AbstractIndices{Int32}, i) === i
        @test convert(AbstractIndices{Int64}, i)::UnorderedIndices{Int64} == i

        @test convert(UnorderedIndices{Int32}, i) === i
        @test convert(UnorderedIndices{Int64}, i)::UnorderedIndices{Int64} == i

        @test convert(UnorderedIndices{Int32}, ai)::UnorderedIndices{Int32} == i
        @test convert(UnorderedIndices{Int64}, ai)::UnorderedIndices{Int64} == i
    end

    @testset "rand" begin
        inds = UnorderedIndices(["a", "b", "c", "d", "e"])
        for i = 1:100
            @test rand(inds) in ["a", "b", "c", "d", "e"]
        end

        delete!(inds, "b") # Test handling of deleted slots
        for i = 1:100
            @test rand(inds) in ["a", "c", "d", "e"]
        end
    end

    # TODO: token interface
end
