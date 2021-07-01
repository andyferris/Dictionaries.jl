@testset "filter" begin
    inds = Indices([1,2,3,4,5])

    @test isequal(filter(iseven, inds)::Indices, Indices([2, 4]))
    @test isequal(filter(isodd, inds)::Indices, Indices([1, 3, 5]))
 
    @test isequal(filterview(iseven, inds)::Dictionaries.FilteredIndices, Indices([2, 4]))
    @test isequal(filterview(isodd, inds)::Dictionaries.FilteredIndices, Indices([1, 3, 5]))
    @test filterview(iseven, inds)[2] == 2
    @test length(filterview(iseven, inds)) == 2
    @test_throws IndexError filterview(isodd, inds)[2]
    @test in(2, filterview(iseven, inds))
    @test !in(2, filterview(isodd, inds))

    @test collect(reverse(filterview(iseven, inds))) == [4, 2]

    @test empty(filterview(iseven, inds))::Indices == Indices{Int}()
    @test keys(similar(filterview(iseven, inds))::Dictionary) == Indices{Int}([2, 4])

    filter!(iseven, inds)
    @test isequal(inds, Indices([2, 4]))

    d = Dictionary([1,2,3,4,5], [1,3,2,4,5])

    @test isequal(filter(iseven, d)::Dictionary, dictionary([3=>2, 4=>4]))
    @test isequal(filter(isodd, d)::Dictionary, dictionary([1=>1, 2=>3, 5=>5]))

    @test isequal(filterview(iseven, d)::Dictionaries.FilteredDictionary, dictionary([3=>2, 4=>4]))
    @test isequal(filterview(isodd, d)::Dictionaries.FilteredDictionary, dictionary([1=>1, 2=>3, 5=>5]))
    @test filterview(iseven, d)[3] == 2
    @test length(filterview(iseven, d)) == 2
    @test_throws IndexError filterview(isodd, d)[3]

    @test empty(filterview(iseven, d))::Dictionary{Int, Int} == Dictionary{Int, Int}()
    @test keys(similar(filterview(iseven, d))::Dictionary) == Indices{Int}([3, 4])

    filter!(iseven, d)
    @test isequal(d, Dictionary([3,4],[2,4]))

    for _ in 1:100
        @test rand(filterview(iseven, d)) in [2,4]
    end
    @test_throws ArgumentError rand(filterview(x -> false, d))
end