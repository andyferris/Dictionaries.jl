@testset "HashDictionary" begin
    @test HashDictionary() isa HashDictionary{Any, Any}

    d = HashDictionary{Int64, Int64}()

    @test eltype(d) === Int64
    @test keytype(d) === Int64
    @test tokentype(d) === Int
    @test Base.IteratorSize(d) === Base.HasLength()
    @test isinsertable(d)
    @test length(d) == 0
    @test isempty(d)
    @test isempty(keys(d))
    @test d == d
    @test d == copy(d)
    @test d == HashDictionary(copy(keys(d)), d)
    @test isequal(d, d)
    @test isequal(copy(d), d)
    @test isequal(HashDictionary(copy(keys(d)), d), d)
    @test !isless(d, d)
    @test !isless(copy(d), d)
    @test !isless(HashDictionary(copy(keys(d)), d), d)
    @test cmp(d, d) == 0
    @test cmp(copy(d), d) == 0
    @test cmp(HashDictionary(copy(keys(d)), d), d) == 0
    @test_throws IndexError d[10]
    @test get(d, 10, 15) == 15
    @test length(unset!(d, 10)) == 0
    io = IOBuffer(); print(io, d); @test String(take!(io)) == "{}"
    io = IOBuffer(); show(io, MIME"text/plain"(), d); @test String(take!(io)) == "0-element HashDictionary{Int64,Int64}"
    @test_throws IndexError d[10] = 11
    @test_throws IndexError delete!(d, 10)

    insert!(d, 10, 11)

    @test d[10] == 11
    @test get(d, 10, 15) == 11
    @test get!(d, 10, 15) == 11
    @test length(d) == 1
    @test keys(d) === keys(keys(d))
    @test unique(d)::HashIndices{Int64} == HashIndices([11])
    @test !isempty(d)
    @test d == d
    @test d == copy(d)
    @test d == HashDictionary(copy(keys(d)), d)
    @test d != empty(d)
    @test empty(d) != d
    @test fill(0, d) != d
    @test d != fill(0, d)
    @test fill(0, copy(keys(d))) != d
    @test d != fill(0, copy(keys(d)))
    @test isequal(d, d)
    @test isequal(copy(d), d)
    @test isequal(HashDictionary(copy(keys(d)), d), d)
    @test !isequal(d, empty(d))
    @test !isequal(empty(d), d)
    @test !isequal(fill(0, d), d) 
    @test !isequal(d, fill(0, d))
    @test !isequal(fill(0, copy(keys(d))), d) 
    @test !isequal(d, fill(0, copy(keys(d))))
    @test !isless(d, d)
    @test !isless(copy(d), d)
    @test !isless(HashDictionary(copy(keys(d)), d), d)
    @test !isless(d, empty(d))
    @test isless(empty(d), d)
    @test isless(fill(0, d), d)
    @test !isless(d, fill(0, d))
    @test isless(fill(0, copy(keys(d))), d)
    @test !isless(d, fill(0, copy(keys(d))))
    @test cmp(d, d) == 0
    @test cmp(copy(d), d) == 0
    @test cmp(HashDictionary(copy(keys(d)), d), d) == 0
    @test cmp(d, empty(d)) == 1
    @test cmp(empty(d), d) == -1
    @test cmp(fill(0, d), d) == -1
    @test cmp(d, fill(0, d)) == 1
    @test cmp(fill(0, copy(keys(d))), d) == -1
    @test cmp(d, fill(0, copy(keys(d)))) == 1
    @test_throws IndexError insert!(d, 10, 12)
    @test d[10] == 11
    set!(d, 10, 12)
    @test length(d) == 1
    @test d[10] == 12
    d[10] = 13
    @test length(d) == 1
    @test d[10] == 13
    io = IOBuffer(); print(io, d); @test String(take!(io)) == "{10 │ 13}"
    io = IOBuffer(); show(io, MIME"text/plain"(), d); @test String(take!(io)) == "1-element HashDictionary{Int64,Int64}\n 10 │ 13"
    @test !isequal(d, empty(d))
    @test isequal(d, copy(d))
    @test isempty(empty(d))

    delete!(d, 10)
    @test isequal(d, HashDictionary{Int64, Int64}())

    @test get!(d, 10, 14) == 14
    @test d[10] == 14
    delete!(d, 10)
    
    for i = 2:2:1000
        insert!(d, i, i+1)
        @test d[i] == i + 1 ? true : (@show i; false)
    end
    @test all(in(i, d) == !iseven(i) for i in 2:2:1000)
    @test all(in(i, keys(d)) == iseven(i) for i in 2:2:1000)
    @test isempty(empty!(d))
   
    # TODO token interface

    @testset "Dict tests from Base" begin
        h = HashDictionary{Int, Int}()

        for i in 1:10000
            insert!(h, i, i+1)
        end
        for i in 1:10000
            @test h[i] == i+1
        end
        for i in 1:2:10000
            delete!(h, i)
        end
        for i in 1:10000
            if iseven(i)
                @test h[i] == i+1
            else
                @test_throws IndexError h[i]
            end
        end
        for i in 1:2:10000
            insert!(h, i, i+1)
        end
        for i in 1:10000
            @test h[i] == i+1
        end
        for i in 1:10000
            delete!(h, i)
        end
        @test isempty(h)
        insert!(h, 77, 100)
        @test h[77] == 100
        for i in 1:10000
            set!(h, i, i+1)
        end
        for i in 1:10000
            @test h[i] == i+1
        end
        for i in 1:2:10000
            delete!(h, i)
        end
        for i in 1:10000
            if iseven(i)
                @test h[i] == i+1
            else
                @test_throws IndexError h[i]
            end
        end
        for i in 10001:20000
            insert!(h, i, i+1)
        end
        for i in 1:10000
            if iseven(i)
                @test h[i] == i+1
            else
                @test_throws IndexError h[i]
            end
        end
        for i in 10000:20000
            @test h[i] == i+1
        end
    end
end