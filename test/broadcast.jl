@testset "broadcast" begin
    i = HashIndices([1,2,3,4,5])

    @test issetequal(pairs((i .+ 1)::HashDictionary), [1=>2, 2=>3, 3=>4, 4=>5, 5=>6])
    @test issetequal(pairs(Base.Broadcast.broadcasted(+, i, 1)::BroadcastedDictionary), [1=>2, 2=>3, 3=>4, 4=>5, 5=>6])

    @test issetequal(pairs((i .+ i)::HashDictionary), [1=>2, 2=>4, 3=>6, 4=>8, 5=>10])
    @test issetequal(pairs(Base.Broadcast.broadcasted(+, i, i)::BroadcastedDictionary), [1=>2, 2=>4, 3=>6, 4=>8, 5=>10])

    @test issetequal(pairs((i .+ copy(i))::HashDictionary), [1=>2, 2=>4, 3=>6, 4=>8, 5=>10])
    @test issetequal(pairs(Base.Broadcast.broadcasted(+, i, copy(i))::BroadcastedDictionary), [1=>2, 2=>4, 3=>6, 4=>8, 5=>10])

    d = i .+ 1
    
    @test issetequal(pairs((d .+ 1)::HashDictionary), [1=>3, 2=>4, 3=>5, 4=>6, 5=>7])
    @test issetequal(pairs(Base.Broadcast.broadcasted(+, d, 1)::BroadcastedDictionary), [1=>3, 2=>4, 3=>5, 4=>6, 5=>7])

    @test issetequal(pairs((d .+ d)::HashDictionary), [1=>4, 2=>6, 3=>8, 4=>10, 5=>12])
    @test issetequal(pairs(Base.Broadcast.broadcasted(+, d, d)::BroadcastedDictionary), [1=>4, 2=>6, 3=>8, 4=>10, 5=>12])

    @test issetequal(pairs((d .+ copy(d))::HashDictionary), [1=>4, 2=>6, 3=>8, 4=>10, 5=>12])
    @test issetequal(pairs(Base.Broadcast.broadcasted(+, d, copy(d))::BroadcastedDictionary), [1=>4, 2=>6, 3=>8, 4=>10, 5=>12])
end