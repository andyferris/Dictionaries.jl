@testset "map" begin
    i = HashIndices([1,2,3,4,5])

    @test issetequal(pairs(map(iseven, i)::HashDictionary), [1=>false, 2=>true, 3=>false, 4=>true, 5=>false])
    @test issetequal(pairs(map(isodd, i)::HashDictionary), [1=>true, 2=>false, 3=>true, 4=>false, 5=>true])
 
    @test issetequal(pairs(mapview(iseven, i)::Dictionaries.MappedDictionary), [1=>false, 2=>true, 3=>false, 4=>true, 5=>false])
    @test issetequal(pairs(mapview(isodd, i)::Dictionaries.MappedDictionary), [1=>true, 2=>false, 3=>true, 4=>false, 5=>true])

    d = HashDictionary([1,2,3,4,5], [1,3,2,4,5])

    @test issetequal(pairs(map(iseven, d)::HashDictionary), [1=>false, 2=>false, 3=>true, 4=>true, 5=>false])
    @test issetequal(pairs(map(isodd, d)::HashDictionary), [1=>true, 2=>true, 3=>false, 4=>false, 5=>true])
 
    @test issetequal(pairs(mapview(iseven, d)::Dictionaries.MappedDictionary), [1=>false, 2=>false, 3=>true, 4=>true, 5=>false])
    @test issetequal(pairs(mapview(isodd, d)::Dictionaries.MappedDictionary), [1=>true, 2=>true, 3=>false, 4=>false, 5=>true])
end