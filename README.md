# Dictionaries.jl

*An alternative interface for dictionaries in Julia, for improved productivity and performance*

![Test Status](https://github.com/andyferris/Dictionaries.jl/workflows/Test/badge.svg)
[![Codecov](https://codecov.io/gh/andyferris/Dictionaries.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/andyferris/Dictionaries.jl)

This package is somewhat young - new features are being added and some (low-level) interfaces may be tweaked in the future, but things should be stable enough for general usage. Contributions welcome - please submit an issue or PR!

## Motivation

The high-level goal of this package is to define a new interface for dictionary and set structures which is convenient and efficient for functional data manipulation - including operations such as non-scalar indexing, broadcasting, mapping, filtering, reducing, grouping, and so-on. While Julia comes with built-in `AbstractDict` and `AbstractSet` supertypes, the interfaces for these are not as well established or generic as for `AbstractArray`, the built-in dictionaries implement less of the common data manipulation operations compared to arrays, and it is difficult to work with them in a performant manner.

In this package we aim to devise a cohesive interface for abstract dictionaries (or associative maps), having the common supertype `AbstractDictionary`. A large part of this is working with indices (of arbitrary type) as well as convenient and efficient iteration of the containers. A second goal is to make dictionary manipulation more closely resemble array manipulation, to make it easier for users. Simultaneously, we are pushing the performance of working with dictionaries to be closer to that of working with arrays.

## Getting started

Dictionaries share the common supertype `AbstractDictionary`, and the go-to container in this package is `Dictionary` - which is a new hash-based implementation that serves as a replacement of Julia's inbuilt `Dict` type (using `hash` and `isequal` for key lookup and comparison). The three main difference to `Dict` are that it preserves the order of elements, it iterates much faster, and it iterates values rather than key-value pairs.

### Constructing dictionaries

You can construct one from a list of indices (or keys) and a list of values.

```julia
julia> dict = Dictionary(["a", "b", "c"], [1, 2, 3])
3-element Dictionary{String,Int64}
 "a" │ 1
 "b" │ 2
 "c" │ 3

julia> dict["a"]
1
```

The constructor also accepts any indexable container, preserving the keys and values.
```julia
julia> Dictionary(Dict("a"=>1, "b"=>2, "c"=>3))
3-element Dictionary{String,Int64}
 "c" │ 3
 "b" │ 2
 "a" │ 1
```

If you prefer, you can use the `dictionary` function to create a dictionary from something
that iterates key-value pairs (either as a `Pair` or a two-tuple, etc), somewhat like a
`Dict` constructor.

```julia
julia> dictionary(["a" => 1, "b" => 2, "c" => 3])
3-element Dictionary{String,Int64}
 "a" │ 1
 "b" │ 2
 "c" │ 3
```

One final way to construct a dictionary is using the `index` function, which accepts a
function that constructs a "key" for each element in the collection.

```julia
julia> index(first, ["Alice", "Bob", "Charlie"])
3-element Dictionary{Char,String}
 'A' │ "Alice"
 'B' │ "Bob"
 'C' │ "Charlie"
```

### Accessing dictionaries

The values of `Dictionary` are mutable, or "settable", and can be modified via `setindex!`.
However, just like for `Array`s, new indices (keys) are *never* created or rearranged this way.

```julia
julia> dict["a"] = 10
10

julia> dict
3-element Dictionary{String,Int64}
 "a" │ 10
 "b" │ 2
 "c" │ 3

julia> dict["d"] = 42
ERROR: IndexError("Dictionary does not contain index: d")
Stacktrace:
 [1] setindex!(::Dictionary{String,Int64}, ::Int64, ::String) at /home/ferris/.julia/dev/Dictionaries/src/AbstractDictionary.jl:347
 [2] top-level scope at REPL[7]:1
```

The indices of `Dictionary` are said to be "insertable" - indices can be added or removed with the `insert!` and `delete!` functions.

```
julia> insert!(dict, "d", 42)
4-element Dictionary{String,Int64}
 "a" │ 10
 "b" │ 2
 "c" │ 3
 "d" │ 42

julia> delete!(dict, "d")
3-element Dictionary{String,Int64}
 "a" │ 10
 "b" │ 2
 "c" │ 3
```

Note that `insert!` and `delete!` are precise in the sense that `insert!` will error if the index already exists, and `delete!` will error if the index does not. The `set!` function provides "upsert" functionality ("update or insert") and `unset!` is useful for removing an index that may or may not exist.

### Working with dictionaries

Dictionaries can be manipulated and transformed using a similar interface to Julia's built-in arrays. The first thing to note is that dictionaries iterate values, so it easy to perform simple analytics on the dictionary values.

```julia
julia> dict = Dictionary(["a", "b", "c"], [1, 2, 3])
3-element Dictionary{String,Int64}
 "a" │ 1
 "b" │ 2
 "c" │ 3

julia> sum(dict)
6

julia> using Statistics; mean(dict)
2.0
```

Mapping and broadcasting also function as-per arrays, preserving the indices and transforming the corresponding values.

```julia
julia> map(iseven, dict)
3-element Dictionary{String,Bool}
 "a" │ false
 "b" │ true
 "c" │ false

julia> map(*, dict, dict)
3-element Dictionary{String,Int64}
 "a" │ 1
 "b" │ 4
 "c" │ 9

julia> dict .+ 1
3-element Dictionary{String,Int64}
 "a" │ 2
 "b" │ 3
 "c" │ 4
```

There is a `mapview` function, which is the lazy version of the above.

Filtering a dictionary also preserves the keys, dropping the remainder.

```julia
julia> filter(isodd, dict)
2-element Dictionary{String,Bool}
 "a" │ 1
 "c" │ 3
```

The `filterview` function is provided to lazily filter a dictionary, which may occassionally
be more performant when working with larger containers.

The `pairs` function allows access to both the index (key) and value when iterating.

```julia
julia> pairs(dict)
3-element Dictionaries.PairDictionary{String,Int64,Dictionary{String,Int64}}
 "a" │ "a" => 1
 "b" │ "b" => 2
 "c" │ "c" => 3

julia> map(((k,v),) -> k^v, pairs(dict))
3-element Dictionary{String,String}
 "a" │ "a"
 "b" │ "bb"
 "c" │ "ccc"
```

### Indices

The indices of a dictionary are unique, and form a set (in the mathematical sense). You can get the indices for any dictionary with the `keys` function.

```julia
julia> keys(dict)
3-element Indices{String}
 "a"
 "b"
 "c"
```

Whenever you call `keys(::AbstractDictionary)`, you always receive an `AbstractIndices` in return. 
`Indices` shares a similar implementation to `Base.Set` and can be used to perform set operations including `union`, `intersect`, `setdiff`, `symdiff`, and mutating counterparts. You can construct one from any iterable of unique elements.

```julia
julia> inds = Indices(["a", "b", "c"])
3-element Indices{String}
 "a"
 "b"
 "c"
```

You can also use the `distinct` function, which is similar to `unique` from `Base`, to construct indices where the input may not be unique.

```julia
julia> distinct([1,2,3,3])
3-element Indices{Int64}
 1
 2
 3
```

The `distinct` function may be considered as useful replacement of `unique` in many cases, as the `unique` function internally constructs a hashmap (`Set`) anyway before returning a `Vector`. However, a `Indices` iterates as fast as `Vector` and in many cases it can be useful to be able to `map` it into a dictionary. 

`Indices` are insertable, so you can use `insert!` and `delete!` (or `set!` and `unset!`) to add and remove elements.

```julia
julia> insert!(inds, "d")
4-element Indices{String}
 "a"
 "b"
 "c"
 "d"

julia> delete!(inds, "d")
3-element Indices{String}
 "a"
 "b"
 "c"
```

One crucial property of `AbstractIndices` is that they are a subtype of `AbstractDictionary` (similar to how the `keys` of an `AbstractArray` are always `AbstractArray`s). But how can a set, or indices, be a dictionary? Under `getindex`, they form a map from each element to itself.

```julia
julia> inds["b"]
"b"
```

Thus, if you iterate an `AbstractIndices` you are guaranteed never to get the same value twice, and the collection is a set. All the usual set operations like `union`, `intersect`, `setdiff` and `symdiff` are defined, as well as a newly exported predicate function `disjoint(set1, set2)` which returns `true` if `set1` and `set2` do not intersect/overlap according to an elementwise `isequal` check, and `false` otherwise (note that `Dictionaries.disjoint` is deprecated in favour of `Base.isdisjoint` in Julia 1.5 onwards).

Since all dictionaries have `keys`, even indices must have `keys` - and in this case `keys(inds::AbstractIndices) === inds`.

### Working with indices

While the above properties for `AbstractIndices` may seem a little unnecessary at first, they lead to a variety of useful behavior.

If you wish to perform an operation on each element of a set, you can simply `map` or `broadcast` some indices, and return a dictionary. These operations cannot return an `AbstractIndices` since the mapping may or may not be one-to-one, so the results may not be distinct, while `map`/`broadcast` must preserve the number of elements and the `keys`.

```julia
julia> map(uppercase, inds)
3-element Dictionary{String,String}
 "a" │ "A"
 "b" │ "B"
 "c" │ "C"

julia> inds .* "at"
3-element Dictionary{String,String}
 "a" │ "aat"
 "b" │ "bat"
 "c" │ "cat"
```

You can filter indices.

```julia
julia> filter(in(["a", "b"]), inds)
2-element Indices{String}
 "a"
 "b"
```

To find the subset of dictionary indices/keys that satisfy some constraint on the values, use the `findall` function.

```julia
julia> dict
3-element Dictionary{String,Int64}
 "a" │ 1
 "b" │ 2
 "c" │ 3

julia> inds2 = findall(isodd, dict)
2-element Indices{String}
 "a"
 "c"
```

And, finally, one useful thing you can do with indices is, well, *indexing*. Non-scalar indexing of dictionaries is a little more complicated than that of arrays, since there is an ambiguity on whether the indexer is a *single* index or a collection of indices (for arrays, the scalar indices are integers (or `CartesianIndex`es) so this ambiguity is less of a problem). The [Indexing.jl](https://github.com/andyferris/Indexing.jl) provides the `getindices` function to return a container with the same indices as the indexer, and this is re-exported here.

```julia
julia> getindices(dict, inds2)
2-element Dictionary{String,Int64}
 "a" │ 1
 "c" │ 3
```

It has [been suggested](https://github.com/JuliaLang/julia/issues/30845) to make the syntax `dict.[inds2]` available in Julia in the future for unambiguous non-scalar indexing. 

Lazy non-scalar indexing may be achieved, as usual, with the `view` function.

```julia
julia> view(dict, inds2)
2-element DictionaryView{String,Int64,Indices{String},Dictionary{String,Int64}}
 "a" │ 1
 "c" │ 3
```

Boolean or "logical" indexing is also ambiguous with scalar and non-scalar indexing. Luckily, the `findall` function is a convenient way to convert a Boolean-valued dictionary into indices, which we can use with `getindices`:

```julia
julia> isodd.(dict)
3-element Dictionary{String,Bool}
 "a" │ true
 "b" │ false
 "c" │ true

julia> getindices(dict, findall(isodd.(dict)))
2-element Dictionary{String,Int64}
 "a" │ 1
 "c" │ 3
```

(Who knows - maybe we need syntax for this, too?)

### Other dictionary types

The `ArrayDictionary` container is a simple, iteration-based dictionary that may be faster for smaller collections. It's `keys` are the corresponding `ArrayIndices` type. By default these contain `Vector`s which support mutation, insertion and tokenization, but they can contain other arrays such as [`SVector`](https://github.com/JuliaArrays/StaticArrays.jl)s (which make for good statically-sized dictionaries, with similarities with `Base.ImmutableDict`).

Indices that are based on sort ordering instead of hashing (both in a dense sorted form and as a B-tree or similar) are also planned.

### Factories for dictionary creation

#### Dictionaries with the same indices

The `similar` function is used to create a dictionary with defined indices, but undefined values that can be set/mutated after the fact. `similar(dict, T)` creates a container with the same indices as `dict` and, optionally, a new element type.

```julia
julia> similar(dict, Vector{Int})
3-element Dictionary{String,Array{Int64,1}}
 "a" │ #undef
 "b" │ #undef
 "c" │ #undef
```

The behaviour is the same if `dict` is an `AbstractIndices` - you always get a dictionary with settable/mutable elements. Preserving the indices using `similar` and setting the values provides a huge performance advantage compared to iteratively constructing a new dictionary via insertion (see the bottom of this README).

On the other hand, values can be initialized with the `fill(value, dict)` function.

```julia
julia> fill(42, dict)
3-element Dictionary{String,Int64}
 "a" │ 42
 "b" │ 42
 "c" │ 42
```

The `fill` function can optionally define a wider type than the value, helpful for if you want to assign a default value like `missing` but allow this to be updated later.

```julia
julia> fill(missing, dict, Union{Missing, Int64})
3-element Dictionary{String,Union{Missing, Int64}}
 "a" │ missing
 "b" │ missing
 "c" │ missing
```

Functions `zeros`, `ones`, `falses` and `trues` are defined as a handy alternative to the above in common cases, as are `rand` and `randn`.

```julia
julia> zeros(dict)
3-element Dictionary{String,Float64}
 "a" │ 0.0
 "b" │ 0.0
 "c" │ 0.0

julia> zeros(UInt8, dict)
3-element Dictionary{String,UInt8}
 "a" │ 0x00
 "b" │ 0x00
 "c" │ 0x00
```

Note that the *indices* of the output are not guaranteed to be mutable/insertable - in fact, in the current implementation inserting or deleting indices to the output of the above can corrupt the input container (Julia suffers similar restrictions with `AbstractArray`s with mutable indices, for example changing the size of the indices of a `SubArray` can lead to corruption and segfaults). This also holds true for the output of `map`, `broadcast`, `getindices`, `similar`, `zeros`, `ones`, `falses` and `trues`. If you want a new container with indices you can insert, by sure to `copy` the indices furst, or use `empty` instead.

#### Empty, insertable dictionaries indices

The `empty` function will create an insertable container which is "similar" to the input, with zero elements and the specified type for the indices and values.

 * `empty(x, I)` constructs an empty indices (whether `x` is a dictionary or indices).
 * `empty(x, I, T)` constructs an empty dictionary (whether `x` is a dictionary or indices).
 * `empty(x)` constructs an empty container - indices if `x` are indices, and a dictionary if `x` is a dictionary.

## Types, interfaces and traits

This section will be of primary interest to developers who wish to understand the internals to *Dictionaries.jl* or create their own custom dictionary types.

### `AbstractDictionary`

The common supertype to this package is `AbstractDictionary{I, T}`, which models an indexable container. To implement a simple `AbstractDictionary` all you need to implement is:

 * `getindex(::AbstractDictionary{I, T}, ::I) --> T`
 * `keys(::AbstractDictionary{I, T}) --> AbstractIndices{I}`
 * `isassigned(::AbstractDictionary{I, T}, ::I) --> Bool`

### `AbstractIndices`

Indexable containers in Julia have `keys`, which form a "set" in the mathematic sense of a collection of distinct elements. The `keys` of an `AbstractDictionary{I, T}` must have type `AbstractIndices{I}`. These form a set because no two elements in an `AbstractIndices` can be `isequal`. To implement a simple index type, you need to provide:

 * The `iterate` protocol, returning unique values of type `I`.
 * `in`, such that `in(i, indices)` implies there is an element of `indices` which `isequal` to `i`.
 * Either `length`, or override `IteratorSize` to `SizeUnknown`.

Indices themselves are also dictionaries (much like the indices of `AbstractArray`s are also `AbstractArray`s), and we have the subtyping relationship `AbstractIndices{I} <: AbstractDictionary{I, I}`. Indexing an `AbstractIndices` is always *idempotent*, such that `indices[i] === i`. The `keys` function is also idempotent: `keys(indices::AbstractIndices) === indices` (and therefore `keys(keys(dict::AbstractDictionary)) === keys(dict)`). 

### Non-scalar indexing

Indexing an `AbstractDictionary` follows the interface provided by the *Indexing.jl* package. Since the indices of a dictionary may be of arbitrary type (including being a container such as an array or a dictionary), a function distinct to `getindex` is required to indicate non-scalar indexing.

The expression `dict3 = getindices(dict1, dict2)` follows the following simple rules:

 * The output indices match the indexer, such that `issetequal(keys(dict3), keys(dict2))`.
 * The values of `dict3` come directly from `dict1`, such that `dict3[i] === dict1[dict2[i]]` for all `i in keys(dict2)`.

Non-scalar indexing is simplified such that it is essentially `getindices(dict1, dict2) = map(i -> dict1[i], dict2)`. Note also that `getindices(dict, keys(dict))` has the same keys and values as `dict`, and is synonymous with `getindices(dict, :)`.

These rules match those for `AbstractArray`, including offset arrays. The `view` function will work similarly, and the `setindices!` function from *Indexing.jl* is already implemented (see mutation, below).

### Setting/mutating values

Many dictionary types support setting or mutating the the *values* of the elements. To support mutation, an `AbstractDictionary` should implement:

 * `issettable(::AbstractDictionary)` (returning `true`)
 * `setindex!(dict::AbstractDictionary{I, T}, ::T, ::I}` (returning `dict`)

The `issettable` function is a trait function that indicate whether an `AbstractDictionary` supports `setindex!`.

Because the idempotency property of `AbstractIndices`, indices always have immutable values - but indices can be inserted or deleted (see below).

### Insertion and deletion

If arbitrary indices can be added to or removed from an `AbstractDictionary`, one needs to implement:

 * `isinsertable(::AbstractDictionary)` (returning `true`)
 * `insert!(dict::AbstractDictionary{I, T}, ::I, ::T}` (returning `dict`)
 * `delete!(dict::AbstractDictionary{I, T}, ::I}` (returning `dict`)

The `insert!` and `delete!` always create or remove indices. Calling `insert!` when an index already exists will throw an error, as will attempting to `delete!` an index that does not exist. The function `set!` is provided as an "upsert" (update or insert) operation. Similarly, `unset!` function can be used to ensure a given index does not exist. The `get!` function works as in `Base`.

**NOTE**: `setindex!` can *never* create new indices, unlike with Julia's `AbstractDict` (and many other programming languages!). Always use `set!` to perform an "upsert" operation. This change may seem inconvenient at first, but it is similar to `AbstractArray` and how Julia differs from MATLAB in requiring one to explicitly `push!` to the end of a vector (a much less bug-prone pattern).

`AbstractIndices` may also be insertable, by implementing:

 * `isinsertable(indices)` (returning `true`)
 * `insert!(indices, i)` - add new index `i` to `indices` (will error if index exists)
 * `delete!(indices, i)` - remove an existing index `i` from `indices` (will error if index does not exist).

The `set!` and `unset!` functions behave as expected, as do `union!`, `intersect!`, `setdiff!` and `symdiff!`. Since indices iterate values, the `filter!` function can programmatically trim back a set of indices.

### Tokens

To make operations on dictionaries fast, we need to avoid unnecessary lookups into the dictionary and operations like recomputations of hashes. The token interface makes many things more efficient, especially co-iteration of `similar` containers containing identical `keys`.

#### Implementing the token interface for `AbstractIndices`

A token is a more efficient way of refering to an element of `indices`. Using tokens may
help avoid multiple index lookups for a single operation.

A tokenizable indices must implement:

 * `istokenizable(indices)` (returning `true`)
 * `tokentype(indices) --> T::Type`
 * `iteratetoken(indices, s...)` iterates the tokens of `indices`, like `iterate`
 * `gettoken(indices, i) --> (hasindex::Bool, token)`
 * `gettokenvalue(indices, token)` returning the value of the index at `token`

An `isinsertable` tokenizable indices must implement

 * `gettoken!(indices, i) --> (hadtoken::Bool, token)`
 * `deletetoken!(indices, token) --> indices`

#### Implementing the token interface for `AbstractDictionary`

An tokenizable dictionary must implement:

 * `istokenizable(dict)` (returning `true`)
 * `keys(dict)` must be `istokenizable` and share tokens with `dict`
 * `gettokenvalue(dict, token)` returning the dictionary value at `token`
 * `istokenassigned(dict, token) --> Bool` 

An `issettable` tokenizable dictionary must implement:

 * `settokenvalue!(dict, token)`

An `isinsertable` tokenizable dictionary must implement:

 * `gettoken!(dict, i) --> (hadtoken::Bool, token)`
 * `deletetoken!(dict, token) --> dict`

### Co-iteration implementation notes

When two-or-more dictionaries share the same tokens, co-iterating through their matching
elements becomes much more efficient. By default, the `similar` function on `Indices`
and `ArrayIndices` does not make a copy of the indices. When performing an operation such as
`map!(f, d_out, d_in)`, a check of `keys(d_out) === keys(d_in)` lets us know that the
tokens are equivalent with a constant-time operation. When this is the case, the `map!`
operation can skip lookup entirely, performing zero calls to `hash` and dealing with hash
collisions.

A quick benchmark verifies the result.

```julia
julia> using Dictionaries, BenchmarkTools

julia> d1 = Dictionary(1:10_000_000, 10_000_000:-1:1);

julia> d2 = d1 .+ 1;

julia> @btime map(+, d1, d2);
  25.712 ms (20 allocations: 76.29 MiB)
```

The `copy` below makes `keys(d1) !== keys(d2)`, disabling token co-iteration. It still uses
an iterative approach rather than using mulitple hash-table lookups per element, so it's
relatively snappy.

```julia
julia> @btime map(+, d1, $(Dictionary(copy(keys(d2)), d2)));
  61.615 ms (20 allocations: 76.29 MiB)
```

For a comparitive baseline benchmark, we can try the same with dense vectors.

```julia
julia> v1 = collect(10_000_000:-1:1);

julia> v2 = v1 .+ 1;

julia> @btime map(+, v1, v2);
  27.587 ms (5 allocations: 76.29 MiB)
```

Here, the vector results are in line with the dictionary co-iteration!

Using insertion, instead of preserving the existing indices, is comparitively slow.

```julia
julia> function f(d1, d2)
           out = Dictionary{Int64, Int64}()
           for i in keys(d1)
               insert!(out, i, d1[i] + d2[i])
           end
           return out
       end
f (generic function with 1 method)

julia> @btime f(d1, d2);
  2.819 s (10000091 allocations: 668.42 MiB)
```

Unfortunately, insertion appears to be the idiomatic way of doing things with `Base.Dict`.
Compare the above to:

```julia
julia> dict1 = Dict(pairs(d1)); dict2 = Dict(pairs(d2));

julia> function g(d1, d2)
           out = Dict{Int64, Int64}()
           for i in keys(d1)
               out[i] = d1[i] + d2[i]
           end
           return out
       end
g (generic function with 1 method)

julia> @btime g(dict1, dict2);
  9.507 s (72 allocations: 541.17 MiB)
```

The result is similar with generators, which is possibly the easiest way of dealing with
`Base.Dict`.

```julia
julia> @btime Dict(i => dict1[i] + dict2[i] for i in keys(dict1));
  13.046 s (89996503 allocations: 2.02 GiB)
```

This represents a 500x speedup between the first example with `Dictionary` to this last
example with `Base.Dict`.
