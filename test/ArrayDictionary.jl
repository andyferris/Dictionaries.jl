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
    @test length(unset!(d, 10)) == 0
    io = IOBuffer(); print(io, d); @test String(take!(io)) == "{}"
    if VERSION < v"1.6-"
        io = IOBuffer(); show(io, MIME"text/plain"(), d); @test String(take!(io)) == "0-element ArrayDictionary{Int64,Int64,ArrayIndices{Int64,Array{Int64,1}},Array{Int64,1}}"
    else
        io = IOBuffer(); show(io, MIME"text/plain"(), d); @test String(take!(io)) == "0-element ArrayDictionary{Int64, Int64, ArrayIndices{Int64, Vector{Int64}}, Vector{Int64}}"
    end
    @test_throws IndexError d[10] = 11
    @test_throws IndexError delete!(d, 10)

    insert!(d, 10, 11)

    @test d[10] == 11
    @test haskey(d, 10)
    @test !haskey(d, 100)
    @test get(d, 10, 15) == 11
    @test get!(d, 10, 15) == 11
    @test length(d) == 1
    @test keys(d) === keys(keys(d))
    @test !isempty(d)
    @test isequal(copy(d), d)
    @test_throws IndexError insert!(d, 10, 12)
    @test d[10] == 11
    set!(d, 10, 12)
    @test length(d) == 1
    @test d[10] == 12
    d[10] = 13
    @test length(d) == 1
    @test d[10] == 13
    io = IOBuffer(); print(io, d); @test String(take!(io)) == "{10 = 13}"
    if VERSION < v"1.6-"
        io = IOBuffer(); show(io, MIME"text/plain"(), d); @test String(take!(io)) == "1-element ArrayDictionary{Int64,Int64,ArrayIndices{Int64,Array{Int64,1}},Array{Int64,1}}\n 10 │ 13"
    else
        io = IOBuffer(); show(io, MIME"text/plain"(), d); @test String(take!(io)) == "1-element ArrayDictionary{Int64, Int64, ArrayIndices{Int64, Vector{Int64}}, Vector{Int64}}\n 10 │ 13"
    end
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

    @test keys(ArrayDictionary([1, 2, 3], undef)::ArrayDictionary{Int, Any}) == Indices([1,2,3])
    @test keys(ArrayDictionary{Int}([1, 2, 3], undef)::ArrayDictionary{Int, Any}) == Indices([1,2,3])
    @test keys(ArrayDictionary{Int, String}([1, 2, 3], undef)::ArrayDictionary{Int, String}) == Indices([1,2,3])

    @testset "rand" begin
        dict = ArrayDictionary(["a", "b", "c", "d", "e"], 1:5)
        for i = 1:100
            @test rand(dict) in 1:5
        end
    end
end