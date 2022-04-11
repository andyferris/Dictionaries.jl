@testset "broadcast" begin
    i = Indices([1,2,3,4,5])

    @test isequal((i .+ 1)::Dictionary, dictionary([1=>2, 2=>3, 3=>4, 4=>5, 5=>6]))
    @test isequal(Base.Broadcast.broadcasted(+, i, 1)::BroadcastedDictionary, dictionary([1=>2, 2=>3, 3=>4, 4=>5, 5=>6]))

    @test isequal((i .+ i)::Dictionary, dictionary([1=>2, 2=>4, 3=>6, 4=>8, 5=>10]))
    @test isequal(Base.Broadcast.broadcasted(+, i, i)::BroadcastedDictionary, dictionary([1=>2, 2=>4, 3=>6, 4=>8, 5=>10]))

    @test isequal((i .+ copy(i))::Dictionary, dictionary([1=>2, 2=>4, 3=>6, 4=>8, 5=>10]))
    @test isequal(Base.Broadcast.broadcasted(+, i, copy(i))::BroadcastedDictionary, dictionary([1=>2, 2=>4, 3=>6, 4=>8, 5=>10]))

    @test_throws IndexError Indices([1,2]) .+ Indices([2,3])

    d = i .+ 1
    
    @test isequal((d .+ 1)::Dictionary, dictionary([1=>3, 2=>4, 3=>5, 4=>6, 5=>7]))
    @test isequal(Base.Broadcast.broadcasted(+, d, 1)::BroadcastedDictionary, dictionary([1=>3, 2=>4, 3=>5, 4=>6, 5=>7]))

    @test isequal((d .+ d)::Dictionary, dictionary([1=>4, 2=>6, 3=>8, 4=>10, 5=>12]))
    @test isequal(Base.Broadcast.broadcasted(+, d, d)::BroadcastedDictionary, dictionary([1=>4, 2=>6, 3=>8, 4=>10, 5=>12]))

    @test isequal((d .+ copy(d))::Dictionary, dictionary([1=>4, 2=>6, 3=>8, 4=>10, 5=>12]))
    @test isequal(Base.Broadcast.broadcasted(+, d, copy(d))::BroadcastedDictionary, dictionary([1=>4, 2=>6, 3=>8, 4=>10, 5=>12]))

    d2 = similar(d)
    d2 .= d .+ d
    @test isequal(d2, dictionary([1=>4, 2=>6, 3=>8, 4=>10, 5=>12]))

    d2 .= 0
    @test isequal(d2, dictionary([1=>0, 2=>0, 3=>0, 4=>0, 5=>0]))

    @test_throws IndexError Dictionary([1,2],[1,2]) .+ Dictionary([2,3],[2,3])
end
