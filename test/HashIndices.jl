@testset "HashIndices" begin
    @test HashIndices() isa HashIndices{Any}

    h = HashIndices{Int64}()

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
    io = IOBuffer(); show(io, MIME"text/plain"(), h); @test String(take!(io)) == "0-element HashIndices{Int64}"
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
    io = IOBuffer(); show(io, MIME"text/plain"(), h); @test String(take!(io)) == "1-element HashIndices{Int64}\n 10"
    @test !isequal(h, empty(h))
    @test isequal(h, copy(h))
    @test isempty(empty(h))

    delete!(h, 10.0)

    @test isequal(h, HashIndices{Int64}())

    for i = 2:2:1000
        insert!(h, i)
    end
    @test issetequal(h, HashIndices(2:2:1000))
    @test all(in(i, h) == iseven(i) for i in 2:1000)
    @test isempty(empty!(h))

    # set
    @test length(set!(h, 1)) == 1
    @test length(set!(h, 2, 2)) == 2
    @test length(set!(h, 3.0, 3.0)) == 3
    @test_throws ErrorException set!(h, 4, 5)

    @testset "Comparison" begin
        i1 = HashIndices([1,2,3])
        i2 = HashIndices([1,2])
        i3 = HashIndices([1,2,3,4])
        i4 = HashIndices([3,2,1])

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
    end

    @testset "Adapated from Dict tests from Base" begin
        h = HashIndices{Int}()
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
        res = HashIndices([1,2,3])
        @test distinct(res) === res
        @test isequal(distinct([1,2,3]), res)
        @test isequal(distinct([1,2,3,1]), res)
        @test isequal(distinct([1,2,3]), res)
    end

    @testset "set logic" begin
        i1 = HashIndices([1,2])
        i2 = HashIndices([2,3])
        i3 = HashIndices([3,4])
        i4 = HashIndices([2])

        @test !issetequal(i1, i2)
        @test !(i1 ⊆ i2)
        @test i4 ⊆ i1

        @test !disjoint(i1, i2)
        @test disjoint(i1, i3)
        
        @test isequal(union(i1, i2), HashIndices([1,2,3]))
        @test isequal(union(i2, i1), HashIndices([2,3,1]))
        @test isequal(union(i1, i3), HashIndices([1,2,3,4]))

        @test isequal(intersect(i1, i2), HashIndices([2]))
        @test isequal(intersect(i1, i3), HashIndices([]))

        @test isequal(setdiff(i1, i2), HashIndices([1]))
        @test isequal(setdiff(i1, i3), HashIndices([1, 2]))

        @test isequal(symdiff(i1, i2), HashIndices([1, 3]))
        @test isequal(symdiff(i1, i3), HashIndices([1, 2, 3, 4]))
    end
    # TODO: token interface
end