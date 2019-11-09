@testset "filter" begin
    i = HashIndices([1,2,3,4,5])

    @test issetequal(filter(iseven, i)::HashIndices, [2, 4])
    @test issetequal(filter(isodd, i)::HashIndices, [1, 3, 5])
 
    @test issetequal(filterview(iseven, i)::Dictionaries.FilteredIndices, [2, 4])
    @test issetequal(filterview(isodd, i)::Dictionaries.FilteredIndices, [1, 3, 5])

    d = HashDictionary([1,2,3,4,5], [1,3,2,4,5])

    @test issetequal(pairs(filter(iseven, d)::HashDictionary), [3=>2, 4=>4])
    @test issetequal(pairs(filter(isodd, d)::HashDictionary), [1=>1, 2=>3, 5=>5])

    @test issetequal(pairs(filterview(iseven, d)::Dictionaries.FilteredDictionary), [3=>2, 4=>4])
    @test issetequal(pairs(filterview(isodd, d)::Dictionaries.FilteredDictionary), [1=>1, 2=>3, 5=>5])
end