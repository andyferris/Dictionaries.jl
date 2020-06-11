@testset "filter" begin
    i = HashIndices([1,2,3,4,5])

    @test isequal(filter(iseven, i)::HashIndices, HashIndices([2, 4]))
    @test isequal(filter(isodd, i)::HashIndices, HashIndices([1, 3, 5]))
 
    @test isequal(filterview(iseven, i)::Dictionaries.FilteredIndices, HashIndices([2, 4]))
    @test isequal(filterview(isodd, i)::Dictionaries.FilteredIndices, HashIndices([1, 3, 5]))

    filter!(iseven, i)
    @test isequal(i, HashIndices([2, 4]))

    d = HashDictionary([1,2,3,4,5], [1,3,2,4,5])

    @test isequal(filter(iseven, d)::HashDictionary, dictionary([3=>2, 4=>4]))
    @test isequal(filter(isodd, d)::HashDictionary, dictionary([1=>1, 2=>3, 5=>5]))

    @test isequal(filterview(iseven, d)::Dictionaries.FilteredDictionary, dictionary([3=>2, 4=>4]))
    @test isequal(filterview(isodd, d)::Dictionaries.FilteredDictionary, dictionary([1=>1, 2=>3, 5=>5]))

    filter!(iseven, d)
    @test isequal(d, HashDictionary([3,4],[2,4]))
end