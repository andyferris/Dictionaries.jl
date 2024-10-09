@testset "map" begin
    function _mapview(f, d::AbstractDictionary)
        I = keytype(d)
        T = Base.promote_op(f, eltype(d))
        
        return MappedDictionary{I, T, typeof(f), Tuple{typeof(d)}}(f, (d,))
    end

    i = Indices([1,2,3,4,5])

    @test map(iseven, i)::Dictionary == dictionary([1=>false, 2=>true, 3=>false, 4=>true, 5=>false])
    @test map(isodd, i)::Dictionary == dictionary([1=>true, 2=>false, 3=>true, 4=>false, 5=>true])
 
    @test _mapview(iseven, i)::Dictionaries.MappedDictionary == dictionary([1=>false, 2=>true, 3=>false, 4=>true, 5=>false])
    @test _mapview(isodd, i)::Dictionaries.MappedDictionary == dictionary([1=>true, 2=>false, 3=>true, 4=>false, 5=>true])

    d = Dictionary([1,2,3,4,5], [1,3,2,4,5])

    @test map(iseven, d)::Dictionary == dictionary([1=>false, 2=>false, 3=>true, 4=>true, 5=>false])
    @test map(isodd, d)::Dictionary == dictionary([1=>true, 2=>true, 3=>false, 4=>false, 5=>true])
    @test map(+, d, d)::Dictionary == dictionary([1=>2, 2=>6, 3=>4, 4=>8, 5=>10])
    @test map(+, d, d, d)::Dictionary == dictionary([1=>3, 2=>9, 3=>6, 4=>12, 5=>15])
 
    @test _mapview(iseven, d)::Dictionaries.MappedDictionary == dictionary([1=>false, 2=>false, 3=>true, 4=>true, 5=>false])
    @test _mapview(isodd, d)::Dictionaries.MappedDictionary == dictionary([1=>true, 2=>true, 3=>false, 4=>false, 5=>true])
end
