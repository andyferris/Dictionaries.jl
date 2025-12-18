using Dictionaries
using Test

@testset "reverse" begin
    @testset "indices" begin
        inds = Indices([1,2,3])

        @test first(inds) == 1
        @test firstindex(inds) == 1
        @test last(inds) == 3
        @test lastindex(inds) == 3

        @test reverse(inds)::Indices == Indices([3, 2, 1])
        @test Iterators.reverse(inds)::ReverseIndices == Indices([3, 2, 1])

        @test reverse(convert(ArrayIndices, inds))::ArrayIndices == Indices([3, 2, 1])
        @test Iterators.reverse(convert(ArrayIndices, inds))::ReverseIndices == Indices([3, 2, 1])
    end

    @testset "dictionaries" begin
        d = Dictionary([:a, :b], [1, 2])
        rd = Dictionary([:b, :a], [2, 1])

        @test reverse(d)::Dictionary == rd
        @test Iterators.reverse(d)::ReverseDictionary == rd

        @test reverse(ArrayDictionary(d))::ArrayDictionary == rd
        @test Iterators.reverse(ArrayDictionary(d))::ReverseDictionary == rd

        @test first(d) == 1
        @test last(d) == 2
        @test firstindex(d) == :a
        @test lastindex(d) == :b
        #@test d[begin] == 1 # Parsing issues on earlier versions of Julia...
        @test d[end] == 2
    end
end
