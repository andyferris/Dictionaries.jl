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

    @test_throws IndexError Dictionary([1,2],[1,2]) .+ Dictionary([2,3],[2,3])

    # Issue #63 - Broadcasting only omitted bounds check due to inbounds propagation
    if VERSION < v"1.4" # Compat
        Base.@propagate_inbounds function only(x)
            i = iterate(x)
            @boundscheck if i === nothing
                throw(ArgumentError("Collection is empty, must contain exactly 1 element"))
            end
            (ret, state) = i
            @boundscheck if iterate(x, state) !== nothing
                throw(ArgumentError("Collection has multiple elements, must contain exactly 1 element"))
            end
            return ret
        end
    end
    d2 = Dictionary([:a, :b], [[1,2], [3,4]])
    @test_throws ArgumentError only.(d2)
end
