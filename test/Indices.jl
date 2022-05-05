@testset "Indices" begin
    @test Indices() isa Indices{Any}
    @test_throws IndexError Indices([1, 1])
    @test @inferred(Indices(2*x for x in 1:10))::Indices == Indices(2:2:20)
    @test @inferred(distinct(mod(x, 5) for x in 0:9))::Indices == Indices(0:4)

    h = Indices{Int64}()

    @test isinsertable(h)
    @test length(h) == 0
    @test keys(h) === h
    @test h == h
    @test h == copy(h)
    @test isempty(h)
    @test isequal(copy(h), h)
    @test_throws IndexError h[10]
    @test length(unset!(h, 10)) == 0
    io = IOBuffer(); print(io, h); @test String(take!(io)) == "{}"
    io = IOBuffer(); show(io, MIME"text/plain"(), h); @test String(take!(io)) == "0-element Indices{Int64}"
    @test_throws IndexError delete!(h, 10)

    insert!(h, 10.0)

    @test length(h) == 1
    @test keys(h) === h
    @test unique(h) === h
    @test h == h
    @test h == copy(h)
    @test !isempty(h)
    @test isequal(copy(h), h)
    @test h[10.0] == 10
    @test_throws IndexError insert!(h, 10)
    @test length(set!(h, 10)) == 1
    @test_throws IndexError insert!(h, 10)
    io = IOBuffer(); print(io, h); @test String(take!(io)) == "{10}"
    io = IOBuffer(); show(io, MIME"text/plain"(), h); @test String(take!(io)) == "1-element Indices{Int64}\n 10"
    @test !isequal(h, empty(h))
    @test isequal(h, copy(h))
    @test isempty(empty(h))

    delete!(h, 10.0)

    @test isequal(h, Indices{Int64}())

    for i = 2:2:1000
        insert!(h, i)
    end
    @test issetequal(h, Indices(2:2:1000))
    @test all(in(i, h) == iseven(i) for i in 2:1000)
    @test isempty(empty!(h))

    # set
    @test length(set!(h, 1)) == 1
    @test length(set!(h, 2, 2)) == 2
    @test length(set!(h, 3.0, 3.0)) == 3
    @test_throws ErrorException set!(h, 4, 5)

    @testset "Comparison" begin
        i1 = Indices([1,2,3])
        i2 = Indices([1,2])
        i3 = Indices([1,2,3,4])
        i4 = Indices([3,2,1])

        @test isequal(i1, i1)
        @test hash(i1) == hash(copy(i1))

        @test isless(i2, i1)
        @test !isless(i1, i2)
        @test !isequal(i1, i2)
        @test hash(i1) != hash(i2)

        @test isless(i2, i1)
        @test !isless(i1, i2)
        @test !isequal(i1, i2)

        @test isless(i1, i3)
        @test !isless(i3, i1)
        @test !isequal(i1, i3)

        @test isless(i1, i4)
        @test !isless(i4, i1)
        @test !isequal(i1, i4)

        @test cmp(i1, i1) == 0
        @test cmp(i2, i1) == -1
        @test cmp(i1, i2) == 1
        @test cmp(i3, i1) == 1
        @test cmp(i1, i3) == -1
        @test cmp(i4, i1) == 1
        @test cmp(i1, i4) == -1

        i5 = Indices([1,2,missing])
        @test isequal(i5, i5)
        @test !isless(i5, i5)
        @test (i5 == i5) === missing
        @test (i5 == Indices([1,2,missing])) === missing
    end

    @testset "Adapated from Dict tests from Base" begin
        h = Indices{Int}()
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

    @testset "distinct" begin
        res = Indices([1,2,3])
        @test distinct(res) === res
        @test isequal(distinct([1,2,3]), res)
        @test isequal(distinct([1,2,3,1]), res)
        @test isequal(distinct([1,2,3]), res)
    end

    @testset "set logic" begin
        i1 = Indices([1,2])
        i2 = Indices([2,3])
        i3 = Indices([3,4])
        i4 = Indices([2])

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

        @test isequal(union(i1, i2), Indices([1,2,3]))
        @test isequal(union(i2, i1), Indices([2,3,1]))
        @test isequal(union(i1, i3), Indices([1,2,3,4]))
        @test isequal(union(i1, s1), Indices([1,2,4,5]))

        @test isequal(intersect(i1, i2), Indices([2]))
        @test isequal(intersect(i1, i3), Indices([]))
        @test isequal(intersect(i3, s1), Indices([4]))

        @test isequal(setdiff(i1, i2), Indices([1]))
        @test isequal(setdiff(i1, i3), Indices([1, 2]))
        @test isequal(setdiff(i3, s1), Indices([3]))

        @test isequal(symdiff(i1, i2), Indices([1, 3]))
        @test isequal(symdiff(i1, i3), Indices([1, 2, 3, 4]))
        @test isequal(symdiff(i3, s1), Indices([3, 5]))
    end

    @testset "covert" begin
        i = Indices{Int32}([1,2,3])
        ai = ArrayIndices{Int32}([1,2,3])

        @test convert(AbstractIndices{Int32}, i) === i
        @test convert(AbstractIndices{Int64}, i)::Indices{Int64} == i

        @test convert(Indices{Int32}, i) === i
        @test convert(Indices{Int64}, i)::Indices{Int64} == i

        @test convert(Indices{Int32}, ai)::Indices{Int32} == i
        @test convert(Indices{Int64}, ai)::Indices{Int64} == i
    end

    @testset "rand" begin
        inds = Indices(["a", "b", "c", "d", "e"])
        for i = 1:100
            @test rand(inds) in ["a", "b", "c", "d", "e"]
        end

        delete!(inds, "b") # Test handling of deleted slots
        for i = 1:100
            @test rand(inds) in ["a", "c", "d", "e"]
        end
    end

    @testset "sort" begin
        inds = Indices([1, 3, 2])
        @test sort(inds)::Indices == Indices([1, 2, 3])
        @test sort(inds; rev=true)::Indices == Indices([3, 2, 1])

        indscopy = deepcopy(inds)
        sort!(indscopy)
        @test indscopy == Indices([1, 2, 3])

        indscopy = deepcopy(inds)
        sort!(indscopy; rev=true)
        @test indscopy == Indices([3, 2, 1])
    end

    # TODO: token interface
end
