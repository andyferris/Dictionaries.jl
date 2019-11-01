@testset "HashDictionary" begin
    @test HashDictionary() isa HashDictionary{Any, Any}

    d = HashDictionary{Int64, Int64}()

    @test isinsertable(d)
    @test length(d) == 0
    @test isempty(d)
    @test isempty(keys(d))
    @test isequal(copy(d), d)
    @test_throws IndexError d[10]
    @test length(unset!(d, 10)) == 0
    io = IOBuffer(); print(io, d); @test String(take!(io)) == "0-element HashDictionary{Int64,Int64}"
    @test_throws IndexError d[10] = 11
    @test_throws IndexError delete!(d, 10)

    insert!(d, 11, 10)

    @test length(d) == 1
    @test keys(d) === keys(keys(d))
    @test !isempty(d)
    @test isequal(copy(d), d)
    @test_throws IndexError insert!(d, 12, 10)
    @test d[10] == 11
    set!(d, 12, 10)
    @test length(d) == 1
    @test d[10] == 12
    d[10] = 13
    @test length(d) == 1
    @test d[10] == 13
    io = IOBuffer(); print(io, d); @test String(take!(io)) == "1-element HashDictionary{Int64,Int64}\n 10 => 13"
    @test !isequal(d, empty(d))
    @test isequal(d, copy(d))
    @test isempty(empty(d))

    delete!(d, 10)

    @test isequal(d, HashDictionary{Int64, Int64}())

    
    for i = 2:2:1000
        insert!(d, i+1, i)
    end
    @test all(in(i, d) == !iseven(i) for i in 2:1000)
    @test all(in(i, keys(d)) == iseven(i) for i in 2:1000)
    @test isempty(empty!(d))
   
    # TODO token interface
end