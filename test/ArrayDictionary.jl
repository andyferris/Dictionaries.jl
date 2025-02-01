@testset "ArrayDictionary" begin
    @test ArrayDictionary() isa ArrayDictionary{Any, Any}

    d = ArrayDictionary{Int64, Int64}()

    @test issettable(d)
    @test isinsertable(d)
    @test istokenizable(d)
    @test length(d) == 0
    @test isempty(d)
    @test isempty(keys(d))
    @test isequal(copy(d), d)
    @test_throws IndexError d[10]
    @test get(d, 10, 15) == 15
    @test get(() -> 15, d, 10) == 15
    @test get(d, "10", 15) == 15
    @test get(() -> 15, d, "10") == 15
    @test length(unset!(d, 10)) == 0
    io = IOBuffer(); print(io, d); @test String(take!(io)) == "{}"
    io = IOBuffer(); show(io, MIME"text/plain"(), d); @test String(take!(io)) == "0-element ArrayDictionary{Int64, Int64, ArrayIndices{Int64, Vector{Int64}}, Vector{Int64}}"
    @test_throws IndexError d[10] = 11
    @test_throws IndexError delete!(d, 10)

    insert!(d, 10, 11)

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
    @test !isempty(d)
    @test isequal(copy(d), d)
    @test_throws IndexError insert!(d, 10, 12)
    @test d[10.0] == 11
    set!(d, 10.0, 12.0)
    @test length(d) == 1
    @test d[10] == 12
    setwith!(+, d, 10.0, 2.0)
    @test length(d) == 1
    @test d[10] == 14
    setwith!(+, d, 2.0, 2.0)
    @test length(d) == 2
    @test d[2] == 2
    delete!(d, 2)
    @test length(d) == 1
    d[10.0] = 13.0
    @test d[10] == 13
    io = IOBuffer(); print(io, d); @test String(take!(io)) == "{10 = 13}"
    io = IOBuffer(); show(io, MIME"text/plain"(), d); @test String(take!(io)) == "1-element ArrayDictionary{Int64, Int64, ArrayIndices{Int64, Vector{Int64}}, Vector{Int64}}:\n 10 │ 13"
    @test !isequal(d, empty(d))
    @test isequal(d, copy(d))
    @test isempty(empty(d))

    delete!(d, 10)
    @test isequal(d, ArrayDictionary{Int64, Int64}())

    @test get!(d, 10, 14) == 14
    @test d[10] == 14
    delete!(d, 10)
    
    for i = 2:2:100
        insert!(d, i, i+1)
        @test d[i] == i + 1 ? true : (@show i; false)
    end
    @test all(in(i, d) == !iseven(i) for i in 2:2:100)
    @test all(in(i, keys(d)) == iseven(i) for i in 2:2:100)
    @test isempty(empty!(d))

    @testset "rand" begin
        dict = ArrayDictionary(["a", "b", "c", "d", "e"], 1:5)
        for i = 1:100
            @test rand(dict) in 1:5
        end
    end

    @testset "copy" begin
        dict = ArrayDictionary{Int64, String}([1, 2], undef)

        dictcopy = copy(dict)
        @test dict isa ArrayDictionary{Int64, String}
        @test !sharetokens(dict, dictcopy)
        io = IOBuffer(); show(io, MIME"text/plain"(), dict); @test String(take!(io)) == "2-element ArrayDictionary{Int64, String, ArrayIndices{Int64, Vector{Int64}}, Vector{String}}:\n 1 │ #undef\n 2 │ #undef"
        @test all(!isassigned(dict, i) for i in collect(keys(dict)))
        @test all(!isassigned(dictcopy, i) for i in collect(keys(dictcopy)))
        @test sharetokens(dict, ArrayDictionary{Int64, String}(dict))
        @test pairs(dict) isa Dictionaries.PairDictionary{Int64, String}

        dict = ArrayDictionary([1,2,3,4,5], [1,3,2,4,5])
        dictcopy = copy(dict)
        set!(dict, 6, 7)
        @test length(dict) == 6
        @test length(dictcopy) == 5
    end

    @testset "sort" begin
        dict = ArrayDictionary([1, 3, 2], ['c', 'a', 'b'])
        @test sort(dict)::ArrayDictionary == ArrayDictionary([3, 2, 1], ['a', 'b', 'c'])
        @test sort(dict; rev=true)::ArrayDictionary == ArrayDictionary([1, 2, 3], ['c', 'b', 'a'])

        @test sortperm(dict)::ArrayIndices == ArrayIndices([3, 2, 1])
        @test sortperm(dict; rev=true)::ArrayIndices == ArrayIndices([1, 2, 3])
        @test getindices(dict, sortperm(dict))::ArrayDictionary == ArrayDictionary([3, 2, 1], ['a', 'b', 'c'])
        @test getindices(dict, sortperm(dict; rev=true))::ArrayDictionary ==ArrayDictionary([1, 2, 3], ['c', 'b', 'a'])

        @test sortkeys(dict)::ArrayDictionary == ArrayDictionary([1, 2, 3], ['c', 'b', 'a'])
        @test sortkeys(dict; rev=true)::ArrayDictionary == ArrayDictionary([3, 2, 1], ['a', 'b', 'c'])

        @test sortpairs(dict)::ArrayDictionary == ArrayDictionary([1, 2, 3], ['c', 'b', 'a'])
        @test sortpairs(dict; rev=true)::ArrayDictionary == ArrayDictionary([3, 2, 1], ['a', 'b', 'c'])
        @test sortpairs(dict; by=kv->kv.second=>kv.first)::ArrayDictionary == ArrayDictionary([3, 2, 1], ['a', 'b', 'c'])

        dictcopy = deepcopy(dict)
        sort!(dictcopy)
        @test dictcopy == ArrayDictionary([3, 2, 1], ['a', 'b', 'c'])
        
        dictcopy = deepcopy(dict)
        sort!(dictcopy; rev = true)
        @test dictcopy == ArrayDictionary([1, 2, 3], ['c', 'b', 'a'])

        dictcopy = deepcopy(dict)
        sortkeys!(dictcopy)
        @test dictcopy == ArrayDictionary([1, 2, 3], ['c', 'b', 'a'])

        dictcopy = deepcopy(dict)
        sortkeys!(dictcopy; rev = true)
        @test dictcopy == ArrayDictionary([3, 2, 1], ['a', 'b', 'c'])

        dictcopy = deepcopy(dict)
        sortpairs!(dictcopy)
        @test dictcopy == ArrayDictionary([1, 2, 3], ['c', 'b', 'a'])

        dictcopy = deepcopy(dict)
        sortpairs!(dictcopy; rev = true)
        @test dictcopy == ArrayDictionary([3, 2, 1], ['a', 'b', 'c'])

        dictcopy = deepcopy(dict)
        sortpairs!(dictcopy; by = kv->kv.second=>kv.first)
        @test dictcopy == ArrayDictionary([3, 2, 1], ['a', 'b', 'c'])
    end
end
