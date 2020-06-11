@testset "map" begin
    function _mapview(f, d::AbstractDictionary)
        I = keytype(d)
        T = Core.Compiler.return_type(f, Tuple{eltype(d)})
        
        return MappedDictionary{I, T, typeof(f), Tuple{typeof(d)}}(f, (d,))
    end

    i = Indices([1,2,3,4,5])

    @test issetequal(pairs(map(iseven, i)::Dictionary), [1=>false, 2=>true, 3=>false, 4=>true, 5=>false])
    @test issetequal(pairs(map(isodd, i)::Dictionary), [1=>true, 2=>false, 3=>true, 4=>false, 5=>true])
 
    @test issetequal(pairs(_mapview(iseven, i)::Dictionaries.MappedDictionary), [1=>false, 2=>true, 3=>false, 4=>true, 5=>false])
    @test issetequal(pairs(_mapview(isodd, i)::Dictionaries.MappedDictionary), [1=>true, 2=>false, 3=>true, 4=>false, 5=>true])

    d = Dictionary([1,2,3,4,5], [1,3,2,4,5])

    @test issetequal(pairs(map(iseven, d)::Dictionary), [1=>false, 2=>false, 3=>true, 4=>true, 5=>false])
    @test issetequal(pairs(map(isodd, d)::Dictionary), [1=>true, 2=>true, 3=>false, 4=>false, 5=>true])
 
    @test issetequal(pairs(_mapview(iseven, d)::Dictionaries.MappedDictionary), [1=>false, 2=>false, 3=>true, 4=>true, 5=>false])
    @test issetequal(pairs(_mapview(isodd, d)::Dictionaries.MappedDictionary), [1=>true, 2=>true, 3=>false, 4=>false, 5=>true])
end