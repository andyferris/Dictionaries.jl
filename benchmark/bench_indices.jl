module BenchHashIndices

using BenchmarkTools
using Dictionaries
using OrderedCollections

const suite = BenchmarkGroup()

sizes = [10, 100, 1000, 10_000]
#sizes = [10_000]
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

function build_ordered_set_by_insertion(n)
    out = OrderedSet{Int}()
    for i in 1:n
        push!(out, i)
    end
    return out
end

function build_indices_by_insertion(n)
    out = ArrayIndices{Int}()
    for i in 1:n
        insert!(out, i)
    end
    return out
end

function build_hashindices_by_insertion(n)
    out = Indices{Int}()
    for i in 1:n
        insert!(out, i)
    end
    return out
end

function build_old_hashindices_by_insertion(n)
    out = UnorderedIndices{Int}()
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

function empty_by_deletion(set::OrderedSet, n)
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

function all_in(set, n)
    out = 0
    for i in 1:n
        out += i in set
    end
    return out
end

function not_in(set, n)
    out = 0
    for i in n+1:2n
        out += i in set
    end
    return out
end

function basic_set_test(N)
    h = Set{Int}()
    out = true
    for i in 1:N
        push!(h, i)
    end
    for i in 1:N
        out &= i in h
    end
    for i in 1:2:N
        delete!(h, i)
    end
    for i in 1:N
        out &= (i in h) == iseven(i)
    end
    for i in 1:2:N
        push!(h, i)
    end
    for i in 1:N
        out &= i in h
    end
    for i in 1:N
        delete!(h, i)
    end
    out &= isempty(h)
    push!(h, 7)
    out &= 7 in h
    for i in 1:N
        push!(h, i)
    end
    for i in 1:N
        out &= i in h
    end
    for i in 1:2:N
        delete!(h, i)
    end
    for i in 1:N
        out &= (i in h) == iseven(i)
    end
    for i in N+1:2N
        push!(h, i)
    end
    for i in 1:2N
        out &= (i in h) == (i > N || iseven(i))
    end
    return out
end

function basic_ordered_set_test(N)
    h = OrderedSet{Int}()
    out = true
    for i in 1:N
        push!(h, i)
    end
    for i in 1:N
        out &= i in h
    end
    for i in 1:2:N
        delete!(h, i)
    end
    for i in 1:N
        out &= (i in h) == iseven(i)
    end
    for i in 1:2:N
        push!(h, i)
    end
    for i in 1:N
        out &= i in h
    end
    for i in 1:N
        delete!(h, i)
    end
    out &= isempty(h)
    push!(h, 7)
    out &= 7 in h
    for i in 1:N
        push!(h, i)
    end
    for i in 1:N
        out &= i in h
    end
    for i in 1:2:N
        delete!(h, i)
    end
    for i in 1:N
        out &= (i in h) == iseven(i)
    end
    for i in N+1:2N
        push!(h, i)
    end
    for i in 1:2N
        out &= (i in h) == (i > N || iseven(i))
    end
    return out
end

function basic_indices_test(N)
    h = ArrayIndices{Int}()
    out = true
    for i in 1:N
        insert!(h, i)
    end
    for i in 1:N
        out &= i in h
    end
    for i in 1:2:N
        delete!(h, i)
    end
    for i in 1:N
        out &= (i in h) == iseven(i)
    end
    for i in 1:2:N
        insert!(h, i)
    end
    for i in 1:N
        out &= i in h
    end
    for i in 1:N
        delete!(h, i)
    end
    out &= isempty(h)
    insert!(h, 7)
    out &= 7 in h
    for i in 1:N
        set!(h, i)
    end
    for i in 1:N
        out &= i in h
    end
    for i in 1:2:N
        delete!(h, i)
    end
    for i in 1:N
        out &= (i in h) == iseven(i)
    end
    for i in N+1:2N
        insert!(h, i)
    end
    for i in 1:2N
        out &= (i in h) == (i > N || iseven(i))
    end
    return out
end

function basic_hash_indices_test(N)
    h = Indices{Int}()
    out = true
    for i in 1:N
        insert!(h, i)
    end
    for i in 1:N
        out &= i in h
    end
    for i in 1:2:N
        delete!(h, i)
    end
    for i in 1:N
        out &= (i in h) == iseven(i)
    end
    for i in 1:2:N
        insert!(h, i)
    end
    for i in 1:N
        out &= i in h
    end
    for i in 1:N
        delete!(h, i)
    end
    out &= isempty(h)
    insert!(h, 7)
    out &= 7 in h
    for i in 1:N
        set!(h, i)
    end
    for i in 1:N
        out &= i in h
    end
    for i in 1:2:N
        delete!(h, i)
    end
    for i in 1:N
        out &= (i in h) == iseven(i)
    end
    for i in N+1:2N
        insert!(h, i)
    end
    for i in 1:2N
        out &= (i in h) == (i > N || iseven(i))
    end
    return out
end

function basic_unordered_indices_test(N)
    h = UnorderedIndices{Int}()
    out = true
    for i in 1:N
        insert!(h, i)
    end
    for i in 1:N
        out &= i in h
    end
    for i in 1:2:N
        delete!(h, i)
    end
    for i in 1:N
        out &= (i in h) == iseven(i)
    end
    for i in 1:2:N
        insert!(h, i)
    end
    for i in 1:N
        out &= i in h
    end
    for i in 1:N
        delete!(h, i)
    end
    out &= isempty(h)
    insert!(h, 7)
    out &= 7 in h
    for i in 1:N
        set!(h, i)
    end
    for i in 1:N
        out &= i in h
    end
    for i in 1:2:N
        delete!(h, i)
    end
    for i in 1:N
        out &= (i in h) == iseven(i)
    end
    for i in N+1:2N
        insert!(h, i)
    end
    for i in 1:2N
        out &= (i in h) == (i > N || iseven(i))
    end
    return out
end

pred1 = !=(5)
pred2 = ==(5)

for n in sizes
    r = 1:n
    y = n ÷ 2

    mostly_unique = rand(1:n, n)
    sorted_mostly_unique = sort(mostly_unique)
    rarely_unique = rand(1:floor(Int, sqrt(n)), n)
    sorted_rarely_unique = sort(rarely_unique)

    if n < cutoff 
        vec = collect(r)
        even_vec = collect(2:2:n)
        odd_vec = collect(1:2:n)
    
        indices = ArrayIndices(collect(r))
        even_indices = ArrayIndices(collect(2:2:n))
        odd_indices = ArrayIndices(collect(1:2:n))
    end

    set = Set(r)
    even_set = Set(2:2:n)
    odd_set = Set(1:2:n)

    ordered_set = OrderedSet(r)
    even_ordered_set = OrderedSet(2:2:n)
    odd_ordered_set = OrderedSet(1:2:n)

    hash_indices = Indices(r)
    even_hash_indices = Indices(2:2:n)
    odd_hash_indices = Indices(1:2:n)

    unordered_indices = UnorderedIndices(r)
    even_unordered_indices = UnorderedIndices(2:2:n)
    odd_unordered_indices = UnorderedIndices(1:2:n)

    suite_n = suite["$n"] = BenchmarkGroup()

    s = suite_n["constructor"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable Vector($r))
    s["Set"] = @benchmarkable Set($r)
    s["OrderedSet"] = @benchmarkable OrderedSet($r)
    n < cutoff && (s["ArrayIndices"] = @benchmarkable ArrayIndices($r))
    s["Indices"] = @benchmarkable Indices($r)
    s["UnorderedIndices"] = @benchmarkable UnorderedIndices($r)

    s = suite_n["build by insertion"] = BenchmarkGroup()
    n < cutoff && (s["Vector (push!)"] = @benchmarkable build_set_by_insertion($n))
    s["Set"] = @benchmarkable build_set_by_insertion($n)
    s["OrderedSet"] = @benchmarkable build_ordered_set_by_insertion($n)
    n < cutoff && (s["Set"] = @benchmarkable build_indices_by_insertion($n))
    s["Indices"] = @benchmarkable build_hashindices_by_insertion($n)
    s["UnorderedIndices"] = @benchmarkable build_old_hashindices_by_insertion($n)

    s = suite_n["copy"] = BenchmarkGroup()
    n < cutoff && (s["Vector (pop!)"] = @benchmarkable copy($vec))
    s["Set"] = @benchmarkable copy($set)
    s["OrderedSet"] = @benchmarkable copy($ordered_set)
    n < cutoff && (s["ArrayIndices"] = @benchmarkable copy($indices))
    s["Indices"] = @benchmarkable copy($hash_indices)
    s["UnorderedIndices"] = @benchmarkable copy($unordered_indices)

    s = suite_n["copy and empty by deletion"] = BenchmarkGroup()
    n < cutoff && (s["Vector (pop!)"] = @benchmarkable empty_by_deletion(copy($vec), $n))
    s["Set"] = @benchmarkable empty_by_deletion(copy($set), $n)
    s["OrderedSet"] = @benchmarkable empty_by_deletion(copy($ordered_set), $n)
    n < cutoff && (s["ArrayIndices"] = @benchmarkable empty_by_deletion(copy($indices), $n))
    s["Indices"] = @benchmarkable empty_by_deletion(copy($hash_indices), $n)
    s["UnorderedIndices"] = @benchmarkable empty_by_deletion(copy($unordered_indices), $n)

    s = suite_n["insertion/deletion tests"] = BenchmarkGroup()
    s["Set"] = @benchmarkable basic_set_test($n)
    s["OrderedSet"] = @benchmarkable basic_ordered_set_test($n)
    n < cutoff && (s["ArrayIndices"] = @benchmarkable basic_indices_test($n))
    s["Indices"] = @benchmarkable basic_hash_indices_test($n)
    s["UnorderedIndices"] = @benchmarkable basic_unordered_indices_test($n)

    s = suite_n["insertion/deletion tests"] = BenchmarkGroup()
    s["Set"] = @benchmarkable basic_set_test($n)
    s["OrderedSet"] = @benchmarkable basic_ordered_set_test($n)
    n < cutoff && (s["ArrayIndices"] = @benchmarkable basic_indices_test($n))
    s["Indices"] = @benchmarkable basic_hash_indices_test($n)
    s["UnorderedIndices"] = @benchmarkable basic_unordered_indices_test($n)

    s = suite_n["unique/distinct (high uniqueness, unsorted)"] = BenchmarkGroup()
    s["Vector (unique)"] = @benchmarkable unique($mostly_unique)
    s["Set"] = @benchmarkable Set($mostly_unique)
    s["OrderedSet"] = @benchmarkable OrderedSet($mostly_unique)
    s["Indices (distinct)"] = @benchmarkable distinct($mostly_unique)

    s = suite_n["unique/distinct (high uniqueness, sorted)"] = BenchmarkGroup()
    s["Vector (unique)"] = @benchmarkable unique($sorted_mostly_unique)
    s["Set"] = @benchmarkable Set($sorted_mostly_unique)
    s["OrderedSet"] = @benchmarkable OrderedSet($sorted_mostly_unique)
    s["Indices"] = @benchmarkable distinct($sorted_mostly_unique)

    s = suite_n["unique/distinct (low uniqueness, unsorted)"] = BenchmarkGroup()
    s["Vector (unique)"] = @benchmarkable unique($rarely_unique)
    s["Set"] = @benchmarkable Set($rarely_unique)
    s["OrderedSet"] = @benchmarkable OrderedSet($rarely_unique)
    s["Indices"] = @benchmarkable distinct($rarely_unique)

    s = suite_n["unique/distinct (low uniqueness, sorted)"] = BenchmarkGroup()
    s["Vector (unique)"] = @benchmarkable unique($sorted_rarely_unique)
    s["Set"] = @benchmarkable Set($sorted_rarely_unique)
    s["OrderedSet"] = @benchmarkable OrderedSet($sorted_rarely_unique)
    s["Indices"] = @benchmarkable distinct($sorted_rarely_unique)

    s = suite_n["in"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable all_in($vec, $n))
    s["Set"] = @benchmarkable all_in($set, $n)
    s["OrderedSet"] = @benchmarkable all_in($ordered_set, $n)
    n < cutoff && (s["ArrayIndices"] = @benchmarkable all_in($indices, $n))
    s["Indices"] = @benchmarkable all_in($hash_indices, $n)
    s["UnorderedIndices"] = @benchmarkable all_in($unordered_indices, $n)

    s = suite_n["not in"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable not_in($vec, $n))
    s["Set"] = @benchmarkable not_in($set, $n)
    s["OrderedSet"] = @benchmarkable not_in($ordered_set, $n)
    n < cutoff && (s["ArrayIndices"] = @benchmarkable not_in($indices, $n))
    s["Indices"] = @benchmarkable not_in($hash_indices, $n)
    s["UnorderedIndices"] = @benchmarkable not_in($unordered_indices, $n)

    s = suite_n["count"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable count(iseven, $vec))
    s["Set"] = @benchmarkable count(iseven, $set)
    s["OrderedSet"] = @benchmarkable count(iseven, $ordered_set)
    n < cutoff && (s["ArrayIndices"] = @benchmarkable count(iseven, $indices))
    s["Indices"] = @benchmarkable count(iseven, $hash_indices)
    s["UnorderedIndices"] = @benchmarkable count(iseven, $unordered_indices)

    s = suite_n["sum"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable sum($vec))
    s["Set"] = @benchmarkable sum($set)
    s["OrderedSet"] = @benchmarkable sum($ordered_set)
    n < cutoff && (s["ArrayIndices"] = @benchmarkable sum($indices))
    s["Indices"] = @benchmarkable sum($hash_indices)
    s["UnorderedIndices"] = @benchmarkable sum($unordered_indices)

    s = suite_n["foreach"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable foreachsum($vec))
    s["Set"] = @benchmarkable foreachsum($set)
    s["OrderedSet"] = @benchmarkable foreachsum($ordered_set)
    n < cutoff && (s["ArrayIndices"] = @benchmarkable foreachsum($indices))
    s["Indices"] = @benchmarkable foreachsum($hash_indices)
    s["UnorderedIndices"] = @benchmarkable foreachsum($unordered_indices)

    s = suite_n["filter-map-reduce via generator"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable sum($(2x for x in vec if isodd(x))))
    s["Set"] = @benchmarkable sum($(2x for x in set if isodd(x)))
    s["OrderedSet"] = @benchmarkable sum($(2x for x in ordered_set if isodd(x)))
    n < cutoff && (s["ArrayIndices"] = @benchmarkable sum($(2x for x in indices if isodd(x))))
    s["Indices"] = @benchmarkable sum($(2x for x in hash_indices if isodd(x)))
    s["UnorderedIndices"] = @benchmarkable sum($(2x for x in unordered_indices if isodd(x)))

    s = suite_n["filter (most)"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable filter($pred1, $vec))
    s["Set"] = @benchmarkable filter($pred1, $set)
    s["OrderedSet"] = @benchmarkable filter($pred1, $ordered_set)
    n < cutoff && (s["ArrayIndices"] = @benchmarkable filter($pred1, $indices))
    s["Indices"] = @benchmarkable filter($pred1, $hash_indices)
    s["UnorderedIndices"] = @benchmarkable filter($pred1, $unordered_indices)

    s = suite_n["filter (half)"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable filter(iseven, $vec))
    s["Set"] = @benchmarkable filter(iseven, $set)
    s["OrderedSet"] = @benchmarkable filter(iseven, $ordered_set)
    n < cutoff && (s["ArrayIndices"] = @benchmarkable filter(iseven, $indices))
    s["Indices"] = @benchmarkable filter(iseven, $hash_indices)
    s["UnorderedIndices"] = @benchmarkable filter(iseven, $unordered_indices)

    s = suite_n["filter (few)"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable filter($pred2, $vec))
    s["Set"] = @benchmarkable filter($pred2, $set)
    s["OrderedSet"] = @benchmarkable filter($pred2, $ordered_set)
    n < cutoff && (s["ArrayIndices"] = @benchmarkable filter($pred2, $indices))
    s["Indices"] = @benchmarkable filter($pred2, $hash_indices)
    s["UnorderedIndices"] = @benchmarkable filter($pred2, $unordered_indices)

    s = suite_n["copy and filter! (most)"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable filter!($pred1, copy($vec)))
    s["Set"] = @benchmarkable filter!($pred1, copy($set))
    s["OrderedSet"] = @benchmarkable filter!($pred1, copy($ordered_set))
    n < cutoff && (s["ArrayIndices"] = @benchmarkable filter!($pred1, copy($indices)))
    s["Indices"] = @benchmarkable filter!($pred1, copy($hash_indices))
    s["UnorderedIndices"] = @benchmarkable filter!($pred1, copy($unordered_indices))

    s = suite_n["copy and filter! (half)"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable filter!(iseven, copy($vec)))
    s["Set"] = @benchmarkable filter!(iseven, copy($set))
    s["OrderedSet"] = @benchmarkable filter!(iseven, copy($ordered_set))
    n < cutoff && (s["ArrayIndices"] = @benchmarkable filter!(iseven, copy($indices)))
    s["Indices"] = @benchmarkable filter!(iseven, copy($hash_indices))
    s["UnorderedIndices"] = @benchmarkable filter!(iseven, copy($unordered_indices))

    s = suite_n["copy and filter! (few)"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable filter!($pred2, copy($vec)))
    s["Set"] = @benchmarkable filter!($pred2, copy($set))
    s["OrderedSet"] = @benchmarkable filter!($pred2, copy($ordered_set))
    n < cutoff && (s["ArrayIndices"] = @benchmarkable filter!($pred2, copy($indices)))
    s["Indices"] = @benchmarkable filter!($pred2, copy($hash_indices))
    s["UnorderedIndices"] = @benchmarkable filter!($pred2, copy($unordered_indices))

    s = suite_n["union"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable union($even_vec, $odd_vec))
    s["Set"] = @benchmarkable union($even_set, $odd_set)
    s["OrderedSet"] = @benchmarkable union($even_ordered_set, $odd_ordered_set)
    n < cutoff && (s["ArrayIndices"] = @benchmarkable union($even_indices, $even_indices))
    s["Indices"] = @benchmarkable union($even_hash_indices, $odd_hash_indices)
    s["UnorderedIndices"] = @benchmarkable union($even_unordered_indices, $odd_unordered_indices)

    s = suite_n["intersect (empty)"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable intersect($even_vec, $odd_vec))
    s["Set"] = @benchmarkable intersect($even_set, $odd_set)
    s["OrderedSet"] = @benchmarkable intersect($even_ordered_set, $odd_ordered_set)
    n < cutoff && (s["ArrayIndices"] = @benchmarkable intersect($even_indices, $odd_indices))
    s["Indices"] = @benchmarkable intersect($even_hash_indices, $odd_hash_indices)
    s["UnorderedIndices"] = @benchmarkable intersect($even_unordered_indices, $odd_unordered_indices)

    s = suite_n["intersect (half)"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable intersect($even_vec, $vec))
    s["Set"] = @benchmarkable intersect($even_set, $set)
    s["OrderedSet"] = @benchmarkable intersect($even_ordered_set, $ordered_set)
    n < cutoff && (s["ArrayIndices"] = @benchmarkable intersect($even_indices, $indices))
    s["Indices"] = @benchmarkable intersect($even_hash_indices, $hash_indices)
    s["UnorderedIndices"] = @benchmarkable intersect($even_unordered_indices, $unordered_indices)

    s = suite_n["intersect (whole)"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable intersect($vec, $vec))
    s["Set"] = @benchmarkable intersect($set, $set)
    s["OrderedSet"] = @benchmarkable intersect($ordered_set, $ordered_set)
    n < cutoff && (s["ArrayIndices"] = @benchmarkable intersect($indices, $indices))
    s["Indices"] = @benchmarkable intersect($hash_indices, $hash_indices)
    s["UnorderedIndices"] = @benchmarkable intersect($unordered_indices, $unordered_indices)

    s = suite_n["setdiff (whole)"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable setdiff($even_vec, $odd_vec))
    s["Set"] = @benchmarkable setdiff($even_set, $odd_set)
    s["OrderedSet"] = @benchmarkable setdiff($even_ordered_set, $odd_ordered_set)
    n < cutoff && (s["ArrayIndices"] = @benchmarkable setdiff($even_indices, $odd_indices))
    s["Indices"] = @benchmarkable setdiff($even_hash_indices, $odd_hash_indices)
    s["UnorderedIndices"] = @benchmarkable setdiff($even_unordered_indices, $odd_unordered_indices)

    s = suite_n["setdiff (half)"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable setdiff($even_vec, $vec))
    s["Set"] = @benchmarkable setdiff($even_set, $set)
    s["OrderedSet"] = @benchmarkable setdiff($even_ordered_set, $ordered_set)
    n < cutoff && (s["ArrayIndices"] = @benchmarkable setdiff($even_indices, $indices))
    s["Indices"] = @benchmarkable setdiff($even_hash_indices, $hash_indices)
    s["UnorderedIndices"] = @benchmarkable setdiff($even_unordered_indices, $unordered_indices)

    s = suite_n["setdiff (empty)"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable setdiff($vec, $vec))
    s["Set"] = @benchmarkable setdiff($set, $set)
    s["OrderedSet"] = @benchmarkable setdiff($ordered_set, $ordered_set)
    n < cutoff && (s["ArrayIndices"] = @benchmarkable setdiff($indices, $indices))
    s["Indices"] = @benchmarkable setdiff($hash_indices, $hash_indices)
    s["UnorderedIndices"] = @benchmarkable setdiff($unordered_indices, $unordered_indices)

    s = suite_n["symdiff (whole)"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable symdiff($even_vec, $odd_vec))
    s["Set"] = @benchmarkable symdiff($even_set, $odd_set)
    s["OrderedSet"] = @benchmarkable symdiff($even_ordered_set, $odd_ordered_set)
    n < cutoff && (s["ArrayIndices"] = @benchmarkable symdiff($even_indices, $odd_indices))
    s["Indices"] = @benchmarkable symdiff($even_hash_indices, $odd_hash_indices)
    s["UnorderedIndices"] = @benchmarkable symdiff($even_unordered_indices, $odd_unordered_indices)

    s = suite_n["symdiff (left half)"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable symdiff($vec, $odd_vec))
    s["Set"] = @benchmarkable symdiff($set, $odd_set)
    s["OrderedSet"] = @benchmarkable symdiff($ordered_set, $odd_ordered_set)
    n < cutoff && (s["ArrayIndices"] = @benchmarkable symdiff($indices, $odd_indices))
    s["Indices"] = @benchmarkable symdiff($hash_indices, $odd_hash_indices)
    s["UnorderedIndices"] = @benchmarkable symdiff($unordered_indices, $odd_unordered_indices)

    s = suite_n["symdiff (right half)"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable symdiff($even_vec, $vec))
    s["Set"] = @benchmarkable symdiff($even_set, $set)
    s["OrderedSet"] = @benchmarkable symdiff($even_ordered_set, $ordered_set)
    n < cutoff && (s["ArrayIndices"] = @benchmarkable symdiff($even_indices, $indices))
    s["Indices"] = @benchmarkable symdiff($even_hash_indices, $hash_indices)
    s["UnorderedIndices"] = @benchmarkable symdiff($even_unordered_indices, $unordered_indices)

    s = suite_n["symdiff (empty)"] = BenchmarkGroup()
    n < cutoff && (s["Vector"] = @benchmarkable symdiff($vec, $vec))
    s["Set"] = @benchmarkable symdiff($set, $set)
    s["OrderedSet"] = @benchmarkable symdiff($ordered_set, $ordered_set)
    n < cutoff && (s["ArrayIndices"] = @benchmarkable symdiff($indices, $indices))
    s["Indices"] = @benchmarkable symdiff($hash_indices, $hash_indices)
    s["UnorderedIndices"] = @benchmarkable symdiff($unordered_indices, $unordered_indices)
end

end  # module

BenchHashIndices.suite
