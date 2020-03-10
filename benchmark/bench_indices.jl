module BenchHashIndices

using BenchmarkTools
using Dictionaries

const suite = BenchmarkGroup()

#sizes = [(8 .^ (0:8))...]
sizes = [10, 10_000]

function build_set_by_insertion(n)
    out = Set{Int}()
    for i in 1:n
        push!(out, i)
    end
    return out
end

function build_hashindices_by_insertion(n)
    out = HashIndices{Int}()
    for i in 1:n
        insert!(out, i)
    end
    return out
end

function empty_by_deletion(set::Set, n)
    for i in 1:n
        delete!(set, i)
    end
    return set
end

function empty_by_deletion(indices::HashIndices, n)
    for i in 1:n
        delete!(indices, i)
    end
    return indices
end

function foreachsum(set)
    count = Ref(0)
    foreach(x -> count[] += 1, set)
    return count[]
end


for n in sizes
    r = 1:n
    y = n ÷ 2
    pred1(x) = x != y
    pred2(x) = x == y
    vec = collect(r)
    set = Set(r)
    indices = Indices(collect(r))
    hash_indices = HashIndices(r)

    s = suite["constructor ($n)"] = BenchmarkGroup()
    s["Vector"] = @benchmarkable Vector($r)
    s["Set"] = @benchmarkable Set($r)
    s["Indices"] = @benchmarkable Indices($r)
    s["HashIndices"] = @benchmarkable HashIndices($r)

    s = suite["build by insertion ($n)"] = BenchmarkGroup()
    s["Set"] = @benchmarkable build_set_by_insertion($n)
    s["HashIndices"] = @benchmarkable build_hashindices_by_insertion($n)

    #s = suite["empty by deletion ($n)"] = BenchmarkGroup()
    #s["Set"] = @benchmarkable empty_by_deletion($(Set(r)), $n)
    #s["HashIndices"] = @benchmarkable empty_by_deletion($(HashIndices(r)), $n)
    
    s = suite["in ($n)"] = BenchmarkGroup()
    s["Vector"] = @benchmarkable in($y, $vec)
    s["Set"] = @benchmarkable in($y, $set)
    s["Indices"] = @benchmarkable in($y, $indices)
    s["HashIndices"] = @benchmarkable in($y, $hash_indices)

    s = suite["count ($n)"] = BenchmarkGroup()
    s["Vector"] = @benchmarkable count(iseven, $vec)
    s["Set"] = @benchmarkable count(iseven, $set)
    s["Indices"] = @benchmarkable count(iseven, $indices)
    s["HashIndices"] = @benchmarkable count(iseven, $hash_indices)

    s = suite["sum ($n)"] = BenchmarkGroup()
    s["Vector"] = @benchmarkable sum($vec)
    s["Set"] = @benchmarkable sum($set)
    s["Indices"] = @benchmarkable sum($indices)
    s["HashIndices"] = @benchmarkable sum($hash_indices)

    s = suite["foreach ($n)"] = BenchmarkGroup()
    s["Vector"] = @benchmarkable foreachsum($vec)
    s["Set"] = @benchmarkable foreachsum($set)
    s["Indices"] = @benchmarkable foreachsum($indices)
    s["HashIndices"] = @benchmarkable foreachsum($hash_indices)

    s = suite["filter-map-reduce via generator ($n)"] = BenchmarkGroup()
    s["Vector"] = @benchmarkable sum($(2x for x in vec if isodd(x)))
    s["Set"] = @benchmarkable sum($(2x for x in set if isodd(x)))
    s["Indices"] = @benchmarkable sum($(2x for x in indices if isodd(x)))
    s["HashIndices"] = @benchmarkable sum($(2x for x in hash_indices if isodd(x)))

    s = suite["filter (most) ($n)"] = BenchmarkGroup()
    s["Vector"] = @benchmarkable filter($pred1, $vec)
    s["Set"] = @benchmarkable filter($pred1, $set)
    s["Indices"] = @benchmarkable filter($pred1, $indices)
    s["HashIndices"] = @benchmarkable filter($pred1, $hash_indices)

    s = suite["filter (half) ($n)"] = BenchmarkGroup()
    s["Vector"] = @benchmarkable filter(iseven, $vec)
    s["Set"] = @benchmarkable filter(iseven, $set)
    s["Indices"] = @benchmarkable filter(iseven, $indices)
    s["HashIndices"] = @benchmarkable filter(iseven, $hash_indices)

    s = suite["filter (few) ($n)"] = BenchmarkGroup()
    s["Vector"] = @benchmarkable filter($pred2, $vec)
    s["Set"] = @benchmarkable filter($pred2, $set)
    s["Indices"] = @benchmarkable filter($pred2, $indices)
    s["HashIndices"] = @benchmarkable filter($pred2, $hash_indices)

    # s = suite["filter! (most) ($n)"] = BenchmarkGroup()
    # s["Vector"] = @benchmarkable filter($pred1, $(collect(r)))
    # s["Set"] = @benchmarkable filter($pred1, $(Set(r)))
    # #s["Indices"] = @benchmarkable filter($pred1, $(Indices(collect(r))))
    # s["HashIndices"] = @benchmarkable filter($pred1, $(HashIndices(r)))

    # s = suite["filter! (half) ($n)"] = BenchmarkGroup()
    # s["Vector"] = @benchmarkable filter(iseven, $(collect(r)))
    # s["Set"] = @benchmarkable filter(iseven, $(Set(r)))
    # #s["Indices"] = @benchmarkable filter(iseven, $(Indices(collect(r))))
    # s["HashIndices"] = @benchmarkable filter(iseven, $(HashIndices(r)))

    # s = suite["filter! (few) ($n)"] = BenchmarkGroup()
    # s["Vector"] = @benchmarkable filter!($pred2, $(collect(r)))
    # s["Set"] = @benchmarkable filter!($pred2, $(Set(r)))
    # #s["Indices"] = @benchmarkable filter!($pred2, $(Indices(collect(r))))
    # s["HashIndices"] = @benchmarkable filter!($pred2, $(HashIndices(r)))

    even_set = Set(2:2:n)
    odd_set = Set(1:2:n)
    even_hash_indices = HashIndices(2:2:n)
    odd_hash_indices = HashIndices(1:2:n)

    s = suite["union ($n)"] = BenchmarkGroup()
    s["Set"] = @benchmarkable union($even_set, $odd_set)
    s["HashIndices"] = @benchmarkable union($even_hash_indices, $odd_hash_indices)

    s = suite["intersect (empty) ($n)"] = BenchmarkGroup()
    s["Set"] = @benchmarkable intersect($even_set, $odd_set)
    s["HashIndices"] = @benchmarkable intersect($even_hash_indices, $odd_hash_indices)

    s = suite["intersect (half) ($n)"] = BenchmarkGroup()
    s["Set"] = @benchmarkable intersect($even_set, $set)
    s["HashIndices"] = @benchmarkable intersect($even_hash_indices, $hash_indices)

    s = suite["intersect (whole) ($n)"] = BenchmarkGroup()
    s["Set"] = @benchmarkable intersect($set, $set)
    s["HashIndices"] = @benchmarkable intersect($hash_indices, $hash_indices)

    s = suite["setdiff (whole) ($n)"] = BenchmarkGroup()
    s["Set"] = @benchmarkable setdiff($even_set, $odd_set)
    s["HashIndices"] = @benchmarkable setdiff($even_hash_indices, $odd_hash_indices)

    s = suite["setdiff (half) ($n)"] = BenchmarkGroup()
    s["Set"] = @benchmarkable setdiff($even_set, $set)
    s["HashIndices"] = @benchmarkable setdiff($even_hash_indices, $hash_indices)

    s = suite["setdiff (empty) ($n)"] = BenchmarkGroup()
    s["Set"] = @benchmarkable setdiff($set, $set)
    s["HashIndices"] = @benchmarkable setdiff($hash_indices, $hash_indices)

    s = suite["symdiff (whole) ($n)"] = BenchmarkGroup()
    s["Set"] = @benchmarkable symdiff($even_set, $odd_set)
    s["HashIndices"] = @benchmarkable symdiff($even_hash_indices, $odd_hash_indices)

    s = suite["symdiff (left half) ($n)"] = BenchmarkGroup()
    s["Set"] = @benchmarkable symdiff($set, $odd_set)
    s["HashIndices"] = @benchmarkable symdiff($hash_indices, $hash_indices)

    s = suite["symdiff (right half) ($n)"] = BenchmarkGroup()
    s["Set"] = @benchmarkable symdiff($even_set, $set)
    s["HashIndices"] = @benchmarkable symdiff($even_hash_indices, $odd_hash_indices)

    s = suite["symdiff (empty) ($n)"] = BenchmarkGroup()
    s["Set"] = @benchmarkable symdiff($set, $set)
    s["HashIndices"] = @benchmarkable symdiff($hash_indices, $hash_indices)
end

end  # module

BenchHashIndices.suite
