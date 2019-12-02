@testset "group" begin
    @test Dictionaries.group(identity, 11:20) == HashDictionary(11:20, (x->[x]).(11:20))
    @test Dictionaries.group(iseven, 1:10) == dictionary(true => [2,4,6,8,10], false => [1,3,5,7,9])

    @test Dictionaries.group(iseven, x -> x*2, 1:10) == dictionary(true => [4,8,12,16,20], false => [2,6,10,14,18])

    @test Dictionaries.group((x,y) -> iseven(x+y), (x,y) -> x, 1:10, [1,3,4,2,5,6,4,2,3,9]) == dictionary(true => [1,4,5,6,8,9], false => [2,3,7,10])
end

#@testset "groupunique" begin
    #@test Dictionaries.groupunique(identity, 11:20)::HashIndices{Int} == HashIndices(11:20)
    #@test Dictionaries.groupunique(identity, 11:20)::HashIndices{Int} == HashIndices(11:20)
#end
#=
@testset "groupinds" begin
    @test Dictionaries.groupinds(identity, 11:20) == dictionary(Pair.(11:20, (x->[x]).(1:10)))
    @test Dictionaries.groupinds(iseven, 11:20) == dictionary(true => [2,4,6,8,10], false => [1,3,5,7,9])
end

@testset "groupview" begin
    @test Dictionaries.groupview(identity, 11:20)::Groups == group(identity, 11:20)::dictionary
    @test Dictionaries.groupview(iseven, 11:20)::Groups == group(iseven, 11:20)::dictionary
end
=#
@testset "groupreduce" begin
    @test Dictionaries.groupreduce(identity, +, 1:10) == dictionary(Pair.(1:10, 1:10))
    @test Dictionaries.groupreduce(iseven, +, 1:10) == dictionary(true => 30, false => 25)

    @test Dictionaries.groupreduce(iseven, x -> x*2, +, 1:10) == dictionary(true => 60, false => 50)

    @test Dictionaries.groupreduce(iseven, x -> x*2, +, 1:10; init=10) == dictionary(true => 70, false => 60)

    @test Dictionaries.groupreduce((x,y) -> iseven(x+y), (x,y) -> x+y, +, 1:10, 1:10; init=10) == dictionary(true => 120)
    @test Dictionaries.groupreduce((x,y) -> iseven(x+y), (x,y) -> x+y, +, 1:10, [1,3,4,2,5,6,4,2,3,9]; init=10) == dictionary(true => 62, false => 52)

    @test Dictionaries.groupcount(iseven, 1:10) == dictionary(true => 5, false => 5)
    @test Dictionaries.groupsum(iseven, 1:10) == dictionary(true => 30, false => 25)
    @test Dictionaries.groupprod(iseven, 1:10) == dictionary(true => 2*4*6*8*10, false => 1*3*5*7*9)
end