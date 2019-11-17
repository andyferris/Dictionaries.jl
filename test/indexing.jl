@testset "indexing" begin
    i = HashIndices([1,2,3,4,5])

    @test issetequal(getindices(i, i)::HashIndices, i)
    @test view(i, i) === i

    i2 = HashIndices([1,2,3])
    
    @test issetequal(getindices(i, i2)::HashIndices, i2)
    @test view(i, i2) === i2
    
    d = zeros(Int64, i)::HashDictionary

    @test isequal(getindices(d, i)::HashDictionary, d)
    @test issetequal(pairs(getindices(d, i2)::HashDictionary), [1=>0, 2=>0, 3=>0])
    @test issetequal(pairs(view(d, i2)::DictionaryView), [1=>0, 2=>0, 3=>0])

    setindices!(d, 1, i2)

    @test issetequal(pairs(d), [1=>1, 2=>1, 3=>1, 4=>0, 5=>0])

    d2 = HashDictionary([2,3,4], [3,4,2])

    @test issetequal(pairs(getindices(i, d2)::HashDictionary), [2=>3, 3=>4, 4=>2])
    @test issetequal(pairs(view(i, d2)::DictionaryView), [2=>3, 3=>4, 4=>2])

    @test issetequal(pairs(getindices(d, d2)::HashDictionary), [2=>1, 3=>0, 4=>1])
    @test issetequal(pairs(view(d, d2)::DictionaryView), [2=>1, 3=>0, 4=>1])

    setindices!(d, 2, d2)
    
    @test issetequal(pairs(d), [1=>1, 2=>2, 3=>2, 4=>2, 5=>0])
end