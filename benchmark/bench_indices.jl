module BenchHashIndices

using BenchmarkTools
using Dictionaries

const suite = BenchmarkGroup()

#sizes = [(8 .^ (0:8))...]
sizes = [10 ]#, 100, 1000, 10_000] #, 10_000, 10_000_000]
cutoff = 101

function build_vector_by_insertion(n)
    out = Vector{Int}()
    for i in 1:n
        push!(out, i)
    end
    return out
end

function build_set_by_insertion(n)
    out = Set{Int}()
    for i in 1:n
        push!(out, i)
    end
    return out
end

function build_indices_by_insertion(n)
    out = Indices{Int}()
    for i in 1:n
        insert!(out, i)
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

function build_old_hashindices_by_insertion(n)
    out = Dictionaries.OldHashIndices{Int}()
    for i in 1:n
        insert!(out, i)
    end
    return out
end

function empty_by_deletion(set::Vector, n)
    for i in 1:n
        pop!(set)
    end
    return set
end

function empty_by_deletion(set::Set, n)
    for i in 1:n
        delete!(set, i)
    end
    return set
end

function empty_by_deletion(indices::AbstractIndices, n)
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

    if n < cutoff 
        vec = collect(r)
        even_vec = collect(2:2:n)
        odd_vec = collect(1:2:n)
    
        indices = Indices(collect(r))
        even_indices = Indices(collect(2:2:n))
        odd_indices = Indices(collect(1:2:n))
    end

    set = Set(r)
    even_set = Set(2:2:n)
    odd_set = Set(1:2:n)

    hash_indices = HashIndices(r)
    even_hash_indices = HashIndices(2:2:n)
    odd_hash_indices = HashIndices(1:2:n)

    old_hash_indices = Dictionaries.OldHashIndices(r)
    even_old_hash_indices = Dictionaries.OldHashIndices(2:2:n)
    odd_old_hash_indices = Dictionaries.OldHashIndices(1:2:n)

    suite_n = suite["$n"] = BenchmarkGroup()

    s = suite_n["constructor ($n)"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable Vector($r))
    s["Set"] = @benchmarkable Set($r)
    n < cutoff && (s["Indices"] = @benchmarkable Indices($r))
    s["HashIndices"] = @benchmarkable HashIndices($r)
    s["OldHashIndices"] = @benchmarkable HashIndices($r)

    s = suite_n["build by insertion ($n)"] = BenchmarkGroup()
    n < cutoff && (s["Vector (push!)"] = @benchmarkable build_vector_by_insertion($n))
    s["Set"] = @benchmarkable build_set_by_insertion($n)
    n < cutoff && (s["Set"] = @benchmarkable build_indices_by_insertion($n))
    s["HashIndices"] = @benchmarkable build_hashindices_by_insertion($n)
    s["OldHashIndices"] = @benchmarkable build_old_hashindices_by_insertion($n)

    s = suite_n["empty by deletion ($n)"] = BenchmarkGroup()
    n < cutoff && (s["Vector (pop!)"] = @benchmarkable empty_by_deletion(s, $n) setup=(s=collect($r)) evals=1)
    s["Set"] = @benchmarkable empty_by_deletion(s, $n) setup=(s=Set($r)) evals=1
    n < cutoff && (s["Indices"] = @benchmarkable empty_by_deletion(s, $n) setup=(s=Indices(collect($r))) evals=1)
    s["HashIndices"] = @benchmarkable empty_by_deletion(s, $n) setup=(s=HashIndices($r)) evals=1
    s["OldHashIndices"] = @benchmarkable empty_by_deletion(s, $n) setup=(s=Dictionaries.OldHashIndices($r)) evals=1

    s = suite_n["in ($n)"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable in($y, $vec))
    s["Set"] = @benchmarkable in($y, $set)
    n < cutoff && (s["Indices"] = @benchmarkable in($y, $indices))
    s["HashIndices"] = @benchmarkable in($y, $hash_indices)
    s["OldHashIndices"] = @benchmarkable in($y, $old_hash_indices)

    s = suite_n["count ($n)"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable count(iseven, $vec))
    s["Set"] = @benchmarkable count(iseven, $set)
    n < cutoff && (s["Indices"] = @benchmarkable count(iseven, $indices))
    s["HashIndices"] = @benchmarkable count(iseven, $hash_indices)
    s["OldHashIndices"] = @benchmarkable count(iseven, $old_hash_indices)

    s = suite_n["sum ($n)"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable sum($vec))
    s["Set"] = @benchmarkable sum($set)
    n < cutoff && (s["Indices"] = @benchmarkable sum($indices))
    s["HashIndices"] = @benchmarkable sum($hash_indices)
    s["OldHashIndices"] = @benchmarkable sum($old_hash_indices)

    s = suite_n["foreach ($n)"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable foreachsum($vec))
    s["Set"] = @benchmarkable foreachsum($set)
    n < cutoff && (s["Indices"] = @benchmarkable foreachsum($indices))
    s["HashIndices"] = @benchmarkable foreachsum($hash_indices)
    s["OldHashIndices"] = @benchmarkable foreachsum($old_hash_indices)

    s = suite_n["filter-map-reduce via generator ($n)"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable sum($(2x for x in vec if isodd(x))))
    s["Set"] = @benchmarkable sum($(2x for x in set if isodd(x)))
    n < cutoff && (s["Indices"] = @benchmarkable sum($(2x for x in indices if isodd(x))))
    s["HashIndices"] = @benchmarkable sum($(2x for x in hash_indices if isodd(x)))
    s["OldHashIndices"] = @benchmarkable sum($(2x for x in old_hash_indices if isodd(x)))

    s = suite_n["filter (most) ($n)"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable filter($pred1, $vec))
    s["Set"] = @benchmarkable filter($pred1, $set)
    n < cutoff && (s["Indices"] = @benchmarkable filter($pred1, $indices))
    s["HashIndices"] = @benchmarkable filter($pred1, $hash_indices)
    s["OldHashIndices"] = @benchmarkable filter($pred1, $old_hash_indices)

    s = suite_n["filter (half) ($n)"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable filter(iseven, $vec))
    s["Set"] = @benchmarkable filter(iseven, $set)
    n < cutoff && (s["Indices"] = @benchmarkable filter(iseven, $indices))
    s["HashIndices"] = @benchmarkable filter(iseven, $hash_indices)
    s["OldHashIndices"] = @benchmarkable filter(iseven, $old_hash_indices)

    s = suite_n["filter (few) ($n)"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable filter($pred2, $vec))
    s["Set"] = @benchmarkable filter($pred2, $set)
    n < cutoff && (s["Indices"] = @benchmarkable filter($pred2, $indices))
    s["HashIndices"] = @benchmarkable filter($pred2, $hash_indices)
    s["OldHashIndices"] = @benchmarkable filter($pred2, $old_hash_indices)

    s = suite_n["filter! (most) ($n)"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable filter!($pred1, s) setup=(s=collect($r)) evals=1)
    s["Set"] = @benchmarkable filter!($pred1, s) setup=(s=Set($r)) evals=1
    n < cutoff && (s["Indices"] = @benchmarkable filter!($pred1, s) setup=(s=Indices(collect($r))) evals=1)
    s["HashIndices"] = @benchmarkable filter!($pred1, s) setup=(s=HashIndices($r)) evals=1
    s["OldHashIndices"] = @benchmarkable filter!($pred1, s) setup=(s=Dictionaries.OldHashIndices($r)) evals=1

    s = suite_n["filter! (half) ($n)"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable filter!($iseven, s) setup=(s=collect($r)) evals=1)
    s["Set"] = @benchmarkable filter!($iseven, s) setup=(s=Set($r)) evals=1
    n < cutoff && (s["Indices"] = @benchmarkable filter!($iseven, s) setup=(s=Indices(collect($r))) evals=1)
    s["HashIndices"] = @benchmarkable filter!($iseven, s) setup=(s=HashIndices($r)) evals=1
    s["OldHashIndices"] = @benchmarkable filter!($iseven, s) setup=(s=Dictionaries.OldHashIndices($r)) evals=1

    s = suite_n["filter! (few) ($n)"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable filter!($pred2, s) setup=(s=collect($r)) evals=1)
    s["Set"] = @benchmarkable filter!($pred2, s) setup=(s=Set($r)) evals=1
    n < cutoff && (s["Indices"] = @benchmarkable filter!($pred2, s) setup=(s=Indices(collect($r))) evals=1)
    s["HashIndices"] = @benchmarkable filter!($pred2, s) setup=(s=HashIndices($r)) evals=1
    s["OldHashIndices"] = @benchmarkable filter!($pred2, s) setup=(s=Dictionaries.OldHashIndices($r)) evals=1

    s = suite_n["union ($n)"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable union($even_vec, $odd_vec))
    s["Set"] = @benchmarkable union($even_set, $odd_set)
    n < cutoff && (s["Indices"] = @benchmarkable union($even_indices, $even_indices))
    s["HashIndices"] = @benchmarkable union($even_hash_indices, $odd_hash_indices)
    s["OldHashIndices"] = @benchmarkable union($even_old_hash_indices, $odd_old_hash_indices)

    s = suite_n["intersect (empty) ($n)"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable intersect($even_vec, $odd_vec))
    s["Set"] = @benchmarkable intersect($even_set, $odd_set)
    n < cutoff && (s["Indices"] = @benchmarkable intersect($even_indices, $odd_indices))
    s["HashIndices"] = @benchmarkable intersect($even_hash_indices, $odd_hash_indices)
    s["OldHashIndices"] = @benchmarkable intersect($even_old_hash_indices, $odd_old_hash_indices)

    s = suite_n["intersect (half) ($n)"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable intersect($even_vec, $vec))
    s["Set"] = @benchmarkable intersect($even_set, $set)
    n < cutoff && (s["Indices"] = @benchmarkable intersect($even_indices, $indices))
    s["HashIndices"] = @benchmarkable intersect($even_hash_indices, $hash_indices)
    s["OldHashIndices"] = @benchmarkable intersect($even_old_hash_indices, $old_hash_indices)

    s = suite_n["intersect (whole) ($n)"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable intersect($vec, $vec))
    s["Set"] = @benchmarkable intersect($set, $set)
    n < cutoff && (s["Indices"] = @benchmarkable intersect($indices, $indices))
    s["HashIndices"] = @benchmarkable intersect($hash_indices, $hash_indices)
    s["OldHashIndices"] = @benchmarkable intersect($old_hash_indices, $old_hash_indices)

    s = suite_n["setdiff (whole) ($n)"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable setdiff($even_vec, $odd_vec))
    s["Set"] = @benchmarkable setdiff($even_set, $odd_set)
    n < cutoff && (s["Indices"] = @benchmarkable setdiff($even_indices, $odd_indices))
    s["HashIndices"] = @benchmarkable setdiff($even_hash_indices, $odd_hash_indices)
    s["OldHashIndices"] = @benchmarkable setdiff($even_old_hash_indices, $odd_old_hash_indices)

    s = suite_n["setdiff (half) ($n)"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable setdiff($even_vec, $vec))
    s["Set"] = @benchmarkable setdiff($even_set, $set)
    n < cutoff && (s["Indices"] = @benchmarkable setdiff($even_indices, $indices))
    s["HashIndices"] = @benchmarkable setdiff($even_hash_indices, $hash_indices)
    s["OldHashIndices"] = @benchmarkable setdiff($even_old_hash_indices, $old_hash_indices)

    s = suite_n["setdiff (empty) ($n)"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable setdiff($vec, $vec))
    s["Set"] = @benchmarkable setdiff($set, $set)
    n < cutoff && (s["Indices"] = @benchmarkable setdiff($indices, $indices))
    s["HashIndices"] = @benchmarkable setdiff($hash_indices, $hash_indices)
    s["OldHashIndices"] = @benchmarkable setdiff($old_hash_indices, $old_hash_indices)

    s = suite_n["symdiff (whole) ($n)"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable symdiff($even_vec, $odd_vec))
    s["Set"] = @benchmarkable symdiff($even_set, $odd_set)
    n < cutoff && (s["Indices"] = @benchmarkable symdiff($even_indices, $odd_indices))
    s["HashIndices"] = @benchmarkable symdiff($even_hash_indices, $odd_hash_indices)
    s["OldHashIndices"] = @benchmarkable symdiff($even_old_hash_indices, $odd_old_hash_indices)

    s = suite_n["symdiff (left half) ($n)"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable symdiff($vec, $odd_vec))
    s["Set"] = @benchmarkable symdiff($set, $odd_set)
    n < cutoff && (s["Indices"] = @benchmarkable symdiff($indices, $odd_indices))
    s["HashIndices"] = @benchmarkable symdiff($hash_indices, $odd_hash_indices)
    s["OldHashIndices"] = @benchmarkable symdiff($old_hash_indices, $odd_old_hash_indices)

    s = suite_n["symdiff (right half) ($n)"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable symdiff($even_vec, $vec))
    s["Set"] = @benchmarkable symdiff($even_set, $set)
    n < cutoff && (s["Indices"] = @benchmarkable symdiff($even_indices, $indices))
    s["HashIndices"] = @benchmarkable symdiff($even_hash_indices, $hash_indices)
    s["OldHashIndices"] = @benchmarkable symdiff($even_old_hash_indices, $old_hash_indices)

    s = suite_n["symdiff (empty) ($n)"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable symdiff($vec, $vec))
    s["Set"] = @benchmarkable symdiff($set, $set)
    n < cutoff && (s["Indices"] = @benchmarkable symdiff($indices, $indices))
    s["HashIndices"] = @benchmarkable symdiff($hash_indices, $hash_indices)
    s["OldHashIndices"] = @benchmarkable symdiff($old_hash_indices, $old_hash_indices)
end

end  # module

BenchHashIndices.suite
