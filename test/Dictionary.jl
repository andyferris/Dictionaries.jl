@testset "Dictionary" begin
    @test Dictionary() isa Dictionary{Any, Any}

    d = Dictionary{Int64, Int64}()

    @test eltype(d) === Int64
    @test keytype(d) === Int64
    @test tokentype(d) === Tuple{Int, Int}
    @test Base.IteratorSize(d) === Base.HasLength()
    @test isinsertable(d)
    @test length(d) == 0
    @test isempty(d)
    @test isempty(keys(d))
    @test d == d
    @test d == copy(d)
    @test d == Dictionary(copy(keys(d)), d)
    @test isequal(d, d)
    @test isequal(copy(d), d)
    @test isequal(Dictionary(copy(keys(d)), d), d)
    @test !isless(d, d)
    @test !isless(copy(d), d)
    @test !isless(Dictionary(copy(keys(d)), d), d)
    @test cmp(d, d) == 0
    @test cmp(copy(d), d) == 0
    @test cmp(Dictionary(copy(keys(d)), d), d) == 0
    @test_throws IndexError d[10]
    @test get(d, 10, 15) == 15
    @test length(unset!(d, 10)) == 0
    io = IOBuffer(); print(io, d); @test String(take!(io)) == "{}"
    if VERSION < v"1.6-"
        io = IOBuffer(); show(io, MIME"text/plain"(), d); @test String(take!(io)) == "0-element Dictionary{Int64,Int64}"
    else
        io = IOBuffer(); show(io, MIME"text/plain"(), d); @test String(take!(io)) == "0-element Dictionary{Int64, Int64}"
    end
    @test_throws IndexError d[10] = 11
    @test_throws IndexError delete!(d, 10)

    insert!(d, 10.0, 11.0)

    @test d[10] == 11
    @test get(d, 10, 15) == 11
    @test get!(d, 10, 15) == 11
    @test length(d) == 1
    @test keys(d) === keys(keys(d))
    @test unique(d)::Indices{Int64} == Indices([11])
    @test !isempty(d)
    @test d == d
    @test d == copy(d)
    @test d == Dictionary(copy(keys(d)), d)
    @test d != empty(d)
    @test empty(d) != d
    @test fill(0, d) != d
    @test d != fill(0, d)
    @test fill(0, copy(keys(d))) != d
    @test d != fill(0, copy(keys(d)))
    @test isequal(d, d)
    @test isequal(copy(d), d)
    @test isequal(Dictionary(copy(keys(d)), d), d)
    @test !isequal(d, empty(d))
    @test !isequal(empty(d), d)
    @test !isequal(fill(0, d), d) 
    @test !isequal(d, fill(0, d))
    @test !isequal(fill(0, copy(keys(d))), d) 
    @test !isequal(d, fill(0, copy(keys(d))))
    @test !isless(d, d)
    @test !isless(copy(d), d)
    @test !isless(Dictionary(copy(keys(d)), d), d)
    @test !isless(d, empty(d))
    @test isless(empty(d), d)
    @test isless(fill(0, d), d)
    @test !isless(d, fill(0, d))
    @test isless(fill(0, copy(keys(d))), d)
    @test !isless(d, fill(0, copy(keys(d))))
    @test cmp(d, d) == 0
    @test cmp(copy(d), d) == 0
    @test cmp(Dictionary(copy(keys(d)), d), d) == 0
    @test cmp(d, empty(d)) == 1
    @test cmp(empty(d), d) == -1
    @test cmp(fill(0, d), d) == -1
    @test cmp(d, fill(0, d)) == 1
    @test cmp(fill(0, copy(keys(d))), d) == -1
    @test cmp(d, fill(0, copy(keys(d)))) == 1
    @test_throws IndexError insert!(d, 10, 12)
    @test d[10.0] == 11
    set!(d, 10.0, 12.0)
    @test length(d) == 1
    @test d[10] == 12
    d[10.0] = 13.0
    @test length(d) == 1
    @test d[10] == 13
    io = IOBuffer(); print(io, d); @test String(take!(io)) == "{10 │ 13}"
    if VERSION < v"1.6-"
        io = IOBuffer(); show(io, MIME"text/plain"(), d); @test String(take!(io)) == "1-element Dictionary{Int64,Int64}\n 10 │ 13"
    else
        io = IOBuffer(); show(io, MIME"text/plain"(), d); @test String(take!(io)) == "1-element Dictionary{Int64, Int64}\n 10 │ 13"
    end
    @test !isequal(d, empty(d))
    @test isequal(d, copy(d))
    @test isempty(empty(d))

    delete!(d, 10.0)
    @test isequal(d, Dictionary{Int64, Int64}())

    @test get!(d, 10, 14.0) == 14
    @test d[10] == 14
    delete!(d, 10)
    
    for i = 2:2:1000
        insert!(d, i, i+1)
        @test d[i] == i + 1 ? true : (@show i; false)
    end
    @test all(in(i, d) == !iseven(i) for i in 2:2:1000)
    @test all(in(i, keys(d)) == iseven(i) for i in 2:2:1000)
    @test isempty(empty!(d))
   
    @test get!(() -> 15, d, 10) == 15
    @test get!(() -> 16, d, 10) == 15

    d = Dictionary([:a, :b], [1, 2])
    @test isequal(d, d)
    @test d == d
    @test !isless(d, d)
    d2 = Dictionary((a=1, b=2))
    @test isequal(d, d2)
    @test d == d
    d3 = dictionary([:a=>1, :b=>2])
    @test isequal(d, d3)
    d4 = dictionary(zip([:a, :b], [1, 2]))
    @test isequal(d, d4)
    @test !isless(d, d4)
    @test !isless(d4, d)
    @test hash(d) == hash(d4)

    @test isdictequal(d, copy(d))
    @test isdictequal(Dictionary(['a','b'],[1,2]), Dictionary(['b','a'],[2,1]))
    @test !isdictequal(Dictionary(['a','b'],[1,2]), Dictionary(['b','c'],[2,1]))
    @test !isdictequal(Dictionary(['a','b'],[1,2]), Dictionary(['a','b','c'],[1,2,3]))
    @test !isdictequal(Dictionary(['a','b'],[1,2]), Dictionary(['b','a'],[2,3]))
    
    d5 = Dictionary(['a','b'],[1,missing])
    @test isdictequal(d5, d5) === missing
    @test (d5 == d5) === missing
    d6 = Dictionary(['a','b'],[1,missing])
    @test isdictequal(d5, d5) === missing
    @test (d5 == d5) === missing

    @test isequal(merge(d, d), d)
    @test isequal(merge(d, d2), d)
    
    @test isequal(merge(d, Dictionary([:c], [3])), Dictionary([:a, :b, :c], [1, 2, 3]))
    @test isequal(merge(d, Dictionary([:b, :c], [4, 3])), Dictionary([:a, :b, :c], [1, 4, 3]))

    @test isequal(index(first, ["Alice", "Bob", "Charlie"]), Dictionary(['A', 'B', 'C'], ["Alice", "Bob", "Charlie"]))
    @test isequal(index(first, ["Alice", "Bob", "Charlie", "Conner"]), Dictionary(['A', 'B', 'C'], ["Alice", "Bob", "Charlie"]))

    rd = Dictionary([:b, :a], [2, 1])
    @test reverse(d)::Dictionary == rd
    @test Iterators.reverse(d)::ReverseDictionary == rd
    @test first(d) == 1
    @test last(d) == 2
    @test firstindex(d) == :a
    @test lastindex(d) == :b
    #@test d[begin] == 1 # Parsing issues on earlier versions of Julia...
    @test d[end] == 2

    # TODO token interface

    @testset "Dict tests from Base" begin
        h = Dictionary{Int, Int}()

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

    @testset "dictionary" begin
        res = Dictionary(['a','b','c'], [1,2,3])
        @test isequal(dictionary(pairs(res)), res)
        @test isequal(dictionary(['a'=>1, 'b'=>2, 'c'=>3]), res)
        @test isequal(dictionary(['a'=>1, 'b'=>2, 'c'=>3, 'a'=>4]), res)
        @test isequal(dictionary((k,v) for (k,v) in pairs(res)), res)
    end

    @testset "index" begin
        res = Dictionary(['A','B','C'], ["Alice","Bob","Charlie"])
        @test isequal(index(first, ["Alice", "Bob", "Charlie"]), res)
        @test isequal(index(first, ["Alice", "Bob", "Charlie", "Conner"]), res)
    end

    @testset "Factories" begin
        d = Dictionary(['a','b','c'], [1,2,3])
        @test similar(d) isa Dictionary{Char, Int}
        @test similar(d, Float64) isa Dictionary{Char, Float64}
        @test sharetokens(d, similar(d))

        @test isempty(empty(d)::Dictionary{Char, Int})
        @test isempty(empty(d, Float64)::Indices{Float64})
        @test isempty(empty(d, String, Float64)::Dictionary{String, Float64})

        @test isequal(zeros(d)::Dictionary{Char, Float64}, Dictionary(['a','b','c'],[0.0,0.0,0.0]))
        @test isequal(zeros(Int64, d)::Dictionary{Char, Int64}, Dictionary(['a','b','c'],[0,0,0]))

        @test isequal(ones(d)::Dictionary{Char, Float64}, Dictionary(['a','b','c'],[1.0,1.0,1.0]))
        @test isequal(ones(Int64, d)::Dictionary{Char, Int64}, Dictionary(['a','b','c'],[1,1,1]))

        @test isequal(keys(rand(1:10, d)::Dictionary{Char, Int}), Indices(['a','b','c']))
        @test isequal(keys(randn(d)::Dictionary{Char, Float64}), Indices(['a','b','c']))
    end

    @testset "rand" begin
        dict = Dictionary(["a", "b", "c", "d", "e"], 1:5)
        for i = 1:100
            @test rand(dict) in 1:5
        end

        delete!(dict, "b") # Test handling of deleted slots
        for i = 1:100
            @test rand(dict) in [1, 3, 4, 5]
        end
    end
end