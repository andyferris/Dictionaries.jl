@testset "merge!" begin
    d = dictionary('a':'c' .=> 1:3)
    @test merge!(d, dictionary('a':'c' .=> 0)) === d
    @test d == dictionary('a':'c' .=> 0)

    d = dictionary('a':'c' .=> 1:3)
    @test merge!(+, d, dictionary('a':'c' .=> 0)) === d
    @test d == dictionary('a':'c' .=> 1:3)

    d = dictionary('a':'c' .=> 1:3)
    @test foldl(mergewith!((a, _) -> a + 1), dictionary.('a':'c' .=> 0); init = d) === d
    @test d == dictionary('a':'c' .=> 2:4)
end

@testset "merge" begin
    d = dictionary('a':'c' .=> 1:3)
    @test merge(d, dictionary('a':'c' .=> 0)) == dictionary('a':'c' .=> 0)
    @test d == dictionary('a':'c' .=> 1:3)

    d = dictionary('a':'c' .=> 1:3)
    @test merge(*, d, dictionary('a':'c' .=> 0)) == dictionary('a':'c' .=> 0)
    @test d == dictionary('a':'c' .=> 1:3)

    d = dictionary('a':'c' .=> 1:3)
    @test foldl(mergewith((a, _) -> a + 1), dictionary.('a':'c' .=> 0); init = d) ==
          dictionary('a':'c' .=> 2:4)
    @test d == dictionary('a':'c' .=> 1:3)
end
