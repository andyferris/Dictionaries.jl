@testset "UnorderedDictionary" begin
    @test UnorderedDictionary() isa UnorderedDictionary{Any, Any}

    d = UnorderedDictionary{Int64, Int64}()

    @test eltype(d) === Int64
    @test keytype(d) === Int64
    @test valtype(d) === Int64
    @test tokentype(d) === Int
    @test Base.IteratorSize(d) === Base.HasLength()
    @test isinsertable(d)
    @test length(d) == 0
    @test isempty(d)
    @test isempty(keys(d))
    @test d == d
    @test d == copy(d)
    @test d == UnorderedDictionary(copy(keys(d)), d)
    @test isequal(d, d)
    @test isdictequal(d, d)
    @test isdictequal(copy(d), d)
    @test isdictequal(UnorderedDictionary(copy(keys(d)), d), d)
    @test_throws IndexError d[10]
    @test get(d, 10, 15) == 15
    @test get(() -> 15, d, 10) == 15
    @test get(d, "10", 15) == 15
    @test get(() -> 15, d, "10") == 15
    @test length(unset!(d, 10)) == 0
    io = IOBuffer(); print(io, d); @test String(take!(io)) == "{}"
    if VERSION < v"1.6-"
        io = IOBuffer(); show(io, MIME"text/plain"(), d); @test String(take!(io)) == "0-element UnorderedDictionary{Int64,Int64}"
    else
        io = IOBuffer(); show(io, MIME"text/plain"(), d); @test String(take!(io)) == "0-element UnorderedDictionary{Int64, Int64}"
    end
    @test_throws IndexError d[10] = 11
    @test_throws IndexError delete!(d, 10)

    insert!(d, 10.0, 11.0)

    @test d[10] == 11
    @test haskey(d, 10)
    @test !haskey(d, 100)
    @test get(d, 10, 15) == 11
    @test get(() -> 15, d, 10) == 11
    @test get(d, "10", 15) == 15
    @test get(() -> 15, d, "10") == 15
    @test get!(d, 10, 15) == 11
    @test length(d) == 1
    @test keys(d) === keys(keys(d))
    @test unique(d)::UnorderedIndices{Int64} == UnorderedIndices([11])
    @test !isempty(d)
    @test d == d
    @test d == copy(d)
    @test d == UnorderedDictionary(copy(keys(d)), d)
    @test d != empty(d)
    @test empty(d) != d
    @test fill(0, d) != d
    @test d != fill(0, d)
    @test fill(0, copy(keys(d))) != d
    @test d != fill(0, copy(keys(d)))
    @test isequal(d, d)
    @test isdictequal(d, d)
    @test isdictequal(copy(d), d)
    @test isdictequal(UnorderedDictionary(copy(keys(d)), d), d)
    @test !isdictequal(d, empty(d))
    @test !isdictequal(empty(d), d)
    @test !isdictequal(fill(0, d), d) 
    @test !isdictequal(d, fill(0, d))
    @test !isdictequal(fill(0, copy(keys(d))), d) 
    @test !isdictequal(d, fill(0, copy(keys(d))))
    @test_throws IndexError insert!(d, 10, 12)
    @test d[10.0] == 11
    set!(d, 10.0, 12.0)
    @test length(d) == 1
    @test d[10] == 12
    d[10.0] = 13.0
    @test length(d) == 1
    @test d[10] == 13
    io = IOBuffer(); print(io, d); @test String(take!(io)) == "{10 = 13}"
    if VERSION < v"1.6-"
        io = IOBuffer(); show(io, MIME"text/plain"(), d); @test String(take!(io)) == "1-element UnorderedDictionary{Int64,Int64}\n 10 │ 13"
    else
        io = IOBuffer(); show(io, MIME"text/plain"(), d); @test String(take!(io)) == "1-element UnorderedDictionary{Int64, Int64}\n 10 │ 13"
    end
    @test !isdictequal(d, empty(d))
    @test isdictequal(d, copy(d))
    @test isempty(empty(d))

    delete!(d, 10.0)
    @test isequal(d, UnorderedDictionary{Int64, Int64}())
    @test isdictequal(d, UnorderedDictionary{Int64, Int64}())

    @test get!(d, 10, 14.0) == 14
    @test d[10] == 14
    delete!(d, 10)
    
    for i = 2:2:1000
        insert!(d, i, i+1)
        @test d[i] == i + 1 ? true : (@show i; false)
    end
    @test all(in(i, d) == !iseven(i) for i in 2:2:1000)
    @test all(in(i, keys(d)) == iseven(i) for i in 2:2:1000)
    @test collect(Iterators.reverse(d)) == reverse(collect(d))
    @test isempty(empty!(d))
   
    @test get!(() -> 15, d, 10) == 15
    @test get!(() -> 16, d, 10) == 15

    @test isdictequal(d, copy(d))
    @test isdictequal(UnorderedDictionary(['a','b'],[1,2]), UnorderedDictionary(['b','a'],[2,1]))
    @test !isdictequal(UnorderedDictionary(['a','b'],[1,2]), UnorderedDictionary(['b','c'],[2,1]))
    @test !isdictequal(UnorderedDictionary(['a','b'],[1,2]), UnorderedDictionary(['a','b','c'],[1,2,3]))
    @test !isdictequal(UnorderedDictionary(['a','b'],[1,2]), UnorderedDictionary(['b','a'],[2,3]))

    dmut = UnorderedDictionary([Foo(3), Foo(2)], rand(2))
    dmut_copy = deepcopy(dmut)
    @test all(k -> haskey(dmut_copy, k), keys(dmut_copy))

    mktemp() do path, io
        open(io->serialize(io, dmut), path, "w")
        dmut_ser = deserialize(open(path, "r"))
        @test all(k -> haskey(dmut_ser, k), keys(dmut_ser))
    end
    
    d5 = UnorderedDictionary(['a','b'],[1,missing])
    @test isdictequal(d5, d5) === missing
    @test (d5 == d5) === missing
    d6 = UnorderedDictionary(['a','b'],[1,missing])
    @test isdictequal(d5, d5) === missing
    @test (d5 == d5) === missing
    
    d = UnorderedDictionary([:a, :b, :c], [1, 2, 3])
    @test isdictequal(merge(d, UnorderedDictionary([:c], [3])), UnorderedDictionary([:a, :b, :c], [1, 2, 3]))
    @test isdictequal(merge(d, UnorderedDictionary([:b, :c], [4, 3])), UnorderedDictionary([:a, :b, :c], [1, 4, 3]))

    d7 = UnorderedDictionary(Int32[1, 2], UInt32[1, 2])
    @test convert(UnorderedDictionary{Int64, Int64}, d7)::UnorderedDictionary{Int64, Int64} == UnorderedDictionary(Int64[1, 2], Int64[1, 2])
    d8 = UnorderedDictionary{Int, Int}()
    @test convert(UnorderedDictionary{Int, Int}, d8) === d8

    dict = UnorderedDictionary{Int64, String}([1, 2], undef)

    dictcopy = copy(dict)
    @test dict isa UnorderedDictionary{Int64, String}
    @test sharetokens(dict, dictcopy)
    if VERSION < v"1.6-"
        io = IOBuffer(); show(io, MIME"text/plain"(), dict); str = String(take!(io)); @test(
            str == "2-element UnorderedDictionary{Int64,String}\n 1 │ #undef\n 2 │ #undef" ||
            str == "2-element UnorderedDictionary{Int64,String}\n 2 │ #undef\n 1 │ #undef"
        )
    else
        io = IOBuffer(); show(io, MIME"text/plain"(), dict); str = String(take!(io)); @test(
            str == "2-element UnorderedDictionary{Int64, String}\n 1 │ #undef\n 2 │ #undef" ||
            str == "2-element UnorderedDictionary{Int64, String}\n 2 │ #undef\n 1 │ #undef"
        )
    end
    @test all(!isassigned(dict, i) for i in collect(keys(dict)))
    @test all(!isassigned(dictcopy, i) for i in collect(keys(dictcopy)))
    @test sharetokens(dict, UnorderedDictionary{Int64, String}(dict))
    @test pairs(dict) isa Dictionaries.PairDictionary{Int64, String}

    # TODO token interface

    @testset "filter!" begin
        d = UnorderedDictionary([1,2,3,4,5], [1,3,2,4,5])
        filter!(iseven, d)
        @test isdictequal(d, UnorderedDictionary([3,4], [2,4]))
    end

    @testset "Dict tests from Base" begin
        h = UnorderedDictionary{Int, Int}()

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

    @testset "Factories" begin
        d = UnorderedDictionary(['a','b','c'], [1,2,3])
        @test similar(d) isa UnorderedDictionary{Char, Int}
        @test similar(d, Float64) isa UnorderedDictionary{Char, Float64}
        @test sharetokens(d, similar(d))

        @test isempty(empty(d)::UnorderedDictionary{Char, Int})
        @test isempty(empty(d, Float64)::UnorderedIndices{Float64})
        @test isempty(empty(d, String, Float64)::UnorderedDictionary{String, Float64})

        @test isequal(zeros(d)::UnorderedDictionary{Char, Float64}, UnorderedDictionary(['a','b','c'],[0.0,0.0,0.0]))
        @test isequal(zeros(Int64, d)::UnorderedDictionary{Char, Int64}, UnorderedDictionary(['a','b','c'],[0,0,0]))

        @test isequal(ones(d)::UnorderedDictionary{Char, Float64}, UnorderedDictionary(['a','b','c'],[1.0,1.0,1.0]))
        @test isequal(ones(Int64, d)::UnorderedDictionary{Char, Int64}, UnorderedDictionary(['a','b','c'],[1,1,1]))

        @test isequal(keys(rand(1:10, d)::UnorderedDictionary{Char, Int}), UnorderedIndices(['a','b','c']))
        @test isequal(keys(randn(d)::UnorderedDictionary{Char, Float64}), UnorderedIndices(['a','b','c']))
    end

    @testset "rand" begin
        dict = UnorderedDictionary(["a", "b", "c", "d", "e"], 1:5)
        for i = 1:100
            @test rand(dict) in 1:5
        end

        delete!(dict, "b") # Test handling of deleted slots
        for i = 1:100
            @test rand(dict) in [1, 3, 4, 5]
        end
    end
end
