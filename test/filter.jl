@testset "filter" begin
    i = Indices([1,2,3,4,5])

    @test isequal(filter(iseven, i)::Indices, Indices([2, 4]))
    @test isequal(filter(isodd, i)::Indices, Indices([1, 3, 5]))
 
    @test isequal(filterview(iseven, i)::Dictionaries.FilteredIndices, Indices([2, 4]))
    @test isequal(filterview(isodd, i)::Dictionaries.FilteredIndices, Indices([1, 3, 5]))

    filter!(iseven, i)
    @test isequal(i, Indices([2, 4]))

    d = Dictionary([1,2,3,4,5], [1,3,2,4,5])

    @test isequal(filter(iseven, d)::Dictionary, dictionary([3=>2, 4=>4]))
    @test isequal(filter(isodd, d)::Dictionary, dictionary([1=>1, 2=>3, 5=>5]))

    @test isequal(filterview(iseven, d)::Dictionaries.FilteredDictionary, dictionary([3=>2, 4=>4]))
    @test isequal(filterview(isodd, d)::Dictionaries.FilteredDictionary, dictionary([1=>1, 2=>3, 5=>5]))

    filter!(iseven, d)
    @test isequal(d, Dictionary([3,4],[2,4]))

    for _ in 1:100
        @test rand(filterview(iseven, d)) in [2,4]
    end
    @test_throws ArgumentError rand(filterview(x -> false, d))
end