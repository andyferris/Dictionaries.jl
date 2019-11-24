# Dictionaries.jl

*An alternative interface for dictionaries in Julia*

[![Build Status](https://travis-ci.org/andyferris/Dictionaries.jl.svg?branch=master)](https://travis-ci.org/andyferris/Dictionaries.jl)
[![Codecov](https://codecov.io/gh/andyferris/Dictionaries.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/andyferris/Dictionaries.jl)

The high-level goal of this package is to define a new interface for dictionary and set structures which is convenient for functional data manipulation - including operations such as non-scalar indexing, mapping, filtering, reducing, and so-on.

So far this is a work-in-progress. To get started, check out the `HashDictionary` and `HashIndices` types (similar to `Base.Dict` and `Base.Set`, respectively).

## Motivation

While Julia comes with built-in `AbstractDict` and `AbstractSet` supertypes, the interfaces for these are not as well established or generic as for `AbstractArray`, and dictionaries implement less of the common data manipulation operations compared to arrays - such as broadcasting, `map`, `reduce`, and `filter` (and their mutating counterparts).

In this package we aim to devise a cohesive interface for abstract dictionaries (or associative maps), having the common supertype `AbstractDictionary`. A large part of this is working with indices (of arbitrary type) as well as convenient and efficient iteration of the containers. A second goal is to make dictionary manipulation more closely resemble array manipulation, to make it easier for users.

There are multiple areas of the design space that we can explore for dictionary structures that might make them more convenient for various use cases. Here we are focused on data manipulation - taking in input datasets and processing it with dictionaries as a part of a larger dataflow. A simple of example of where usablility of an interface might differ, Julia's in-built `AbstractDict` will iterate key-value pairs, whereas `AbstractDictionary` chooses to iterate values by default. An example in the data space where this convenient is starting with a dictionary mapping people's names to their age, called `ages` say, and calculating the `mean` age. With `AbstractDictionary`s (as with `AbstractArray`s) we can just use `mean(ages)`.

## Types, interfaces and traits

### `AbstractDictionary`

The common supertype to this package is `AbstractDictionary{I, T}`, which models an indexable container. To implement a simple `AbstractDictionary` all you need to implement is:

 * `getindex(::AbstractDictionary{I, T}, ::I) --> T`
 * `keys(::AbstractDictionary{I, T}) --> AbstractIndices{I}`
 * A constructor `MyDictionary(values, indices)` returning a dictionary with the given `indices` and values set to `values`, matched by iteration. Alternatively, `values` may be a scalar in the broadcasting sense, where all elements are set to the same value.

Built upon just these, a range of useful functionality is provided, generally consistent with `AbstractArray`. **NOTE:** When iterating an `AbstractDictionary`, keep in mind that only the values are iterated (like `AbstractArray`) and not key-value pairs (like `AbstractDict`). This provides a more consistent usage of `map`, `filter`, `reduce`, `broadcast`, and the functions in *SplitApplyCombine.jl* and *Indexing.jl*.

### `AbstractIndices`

Indexable containers in Julia have `keys`, which form a "set" in the mathematic sense of a collection of distinct elements. The `keys` of an `AbstractDictionary{I, T}` must have type `AbstractIndices{I}`. These form a set because no two elements in an `AbstractIndices` can be `isequal`. To implement a simple index type, you need to provide:

 * The `iterate` protocol, returning unique values of type `I`.
 * `in`, such that `in(i, indices)` implies there is an element of `indices` which `isequal` to `i`.
 * A one-argument constructor `MyIndices(iter)` that builds indices by iterating `iter`.

Indices themselves are also dictionaries (much like the indices of `AbstractArray`s are also `AbstractArray`s), and we have the subtyping relationship `AbstractIndices{I} <: AbstractDictionary{I, I}`. Indexing an `AbstractIndex` is always *idempotent*, such that `indices[i] === i`. The `keys` function is also idempotent: `keys(indices::AbstractIndices) === indices` (and therefore `keys(keys(dict::AbstractDictionary)) === keys(dict)`). While indexing into indices may seem unintuitive or obtuse at first, this is quite a natural mathematical formulation that supports the indexing behavior below and the entire `AbstractDictionary` interface. (Dictionaries that iterate values is key to allowing this formulation).

### Non-scalar indexing

Indexing an `AbstractDictionary` follows the interface provided by the *Indexing.jl* package. Since the indices of a dictionary may be of arbitrary type (including being a container such as an array or a dictionary), a function distinct to `getindex` is required to indicate non-scalar indexing.

The expression `dict3 = getindices(dict1, dict2)` follows the following simple rules:

 * The output indices match the indexer, such that `issetequal(keys(dict3), keys(dict2))`.
 * The values of `dict3` come directly from `dict1`, such that `dict3[i] === dict1[dict2[i]]` for all `i in keys(dict2)`.

Non-scalar indexing is simplified such that it is essentially `getindices(dict1, dict2) = map(i -> dict1[i], dict2)`. Note also that `getindices(dict, keys(dict))` has the same keys and values as `dict`, and is synonymous with `getindices(dict, :)`.

These rules match those for `AbstractArray`, including offset arrays. The `view` function will work similarly (work-in-progress), and the `setindices!` function from *Indexing.jl* is already implemented (see mutation, below).

### Setting/mutating values

Many dictionary types support setting or mutating the the *values* of the elements. To support mutation, an `AbstractDictionary` should implement:

 * `issettable(::AbstractDictionary)` (returning `true`)
 * `setindex!(dict::AbstractDictionary{I, T}, ::T, ::I}` (returning `dict`)
 * A constructor `MyDictionary(undef::UndefInitializer, indices)` returning a dictionary with the given `indices` and unitialized values.

The `issettable` function is a trait function that indicate whether an `AbstractDictionary` supports `setindex!`.

Because the idempotency property of `AbstractIndices`, indices always have immutable values - but indices can be inserted or deleted (see below).

### Insertion and deletion

If arbitrary indices can be added to or removed from an `AbstractDictionary`, one needs to implement:

 * `isinsertable(::AbstractDictionary)` (returning `true`)
 * `insert!(dict::AbstractDictionary{I, T}, ::I, ::T}` (returning `dict`)
 * `delete!(dict::AbstractDictionary{I, T}, ::I}` (returning `dict`)
 * A zero-argument constructor `MyDictionary()` returning an empty `MyDictionary`.

The `insert!` and `delete!` always create or remove indices. Calling `insert!` when an index already exists will throw an error, as will attempting to `delete!` an index that does not exist. The function `set!` is provided as an "upsert" (update or insert) operation. Similarly, `unset!` function can be used to ensure a given index does not exist. The `get!` function works as in `Base`.

**NOTE**: `setindex!` can *never* create new indices, unlike with Julia's `AbstractDict` (and many other programming languages!). Always use `set!` to perform an "upsert" operation. This change may seem inconvenient at first, but it is similar to `AbstractArray` and how Julia differs from MATLAB in requiring one to explicitly `push!` to the end of a vector (a much less bug-prone pattern).

Sometimes one wishes to manipulate `AbstractIndices` directly, either to create the keys for a new container or as a part of set logic. To do so, implement:

 * `insert!(indices, i)` - add new index `i` to `indices` (will error if index exists)
 * `delete!(indices, i)` - remove an existing index `i` from `indices` (will error if index does not exist).
 * A zero-argument constructor `MyIndices()` returning an empty `MyIndices`.

The `set!` and `unset!` functions behave as expected, as do `union!`, `intersect!`, `setdiff!` and `symdiff!`. Since indices iterate values, the `filter!` function can programmatically trim back a set of indices.

### Tokens

Make it fast! The concept is similar to `eachindex`, but a bit more generalized. Tokens can also be used to reduce the number of hashing and lookup operations, such as optimizing functions like `set!`, `get!` and `unset!`. Work-in-progress - there is an optimized version of `map` and `map!` that works faster than the equivalent code in `Base`.

### Constructors and factories

We need a generic interface to create new dictionaries. I'd like to make working with an imagined `StaticDictionary` or `DistributedDictionary` or `GPUDictionary` to be seemless, such that generic code "just works" and does the logical performant operations. This work is not complete.

Constructors may need some more thought, and are partly implemented. In general, `MyDictionary()` seems appropriate to create an empty dictionary (or indices). For `AbstractIndices`, it seems appropriate for `MyIndices(iter)` to simply iterate through the input *values*. The form `MyDictionary(undef, ::AbstractIndices)` seems appropriate to create an `issettable` dictionary with given keys but uninitialized values. That suggests `MyDictionary(newvalues, newindices)` as the general initialized form, where the key-value pairings are defined by the mutual iteration of the inputs (or perhaps via `broadcast` so `newvalues` could be e.g. a scalar and this is like `fill`, though this is not yet implemented).

In future work, a single argument `MyDictionary(otherdict)` could copy the keys and values from `otherdict`, and is a bit like `convert`. I also note that sometimes working with `Pair`s is most convenient, so this clashes with the idea of having `MyDictionary(iter)` to iterate `Pair`s like `Dict` would (and `MyDictionary(pairs...)` seems ill-advised). Nevertheless, a solution for `Pair`s would be nice (even if it is a factory-style pattern).

`similar` works like `AbstractArray`: it creates a container that is settable/mutable (`issettable`) and has the same keys as the input. The values are `undef` by default. In general we can overide the element type or keys, using the form (with default values) `newdict = similar(olddict, NewT = eltype(olddict), newkeys = keys(olddict))`. I don't see any reason for the output container to be `isinsertable`.

Sometimes one wants to create an empty insertable container. The `empty` function might be a good candidate, where one can set the index and value types. On the other hand, there is no reason that we can't ask for an `empty` *immutable* or *non-insertable* container (as `empty` is useful even for `Tuple`s) so perhaps a new generic function that ensures `isinsertable` is preferable. (Note: `AbstractArray` has this same problem, where generic code exists in the wild that expects to be able to `push!` to `empty(::AbstractVector)`, for example, which fails for `StaticArray`s).

`fill` seems to be a possible factory that could take an input dictionary, such as `fill(dict, x) = fill!(similar(dict, typeof(x)), x)`. We can define `zeros`, `ones`, `falses` (and `trues`?) from this. There's no reason for `rand`, `randn`, etc not to work as expected.

`copy` is an interesting case - sometimes you do want to keep the same keys and values but you may want to e.g. mutate them afterwards, or add/remove elements, or even simply make a defensive copy. A generic function might be useful for each case?

Sometimes one might want to enable/disable mutation and/or insertion. There has been suggestions of `freeze` and `thaw` for `Array`, for example, but you may also want to `freezekeys` or `thawkeys` (note: similarly in `Base` you may want to fix the length of `Vector` but not it's values).

(As a thought - it might be possible for the above factories to do their work at the type level and then punt to the constructor, similar to *StaticArrays.jl*).

### TODO

 * Some ability to construct dictionaries from a list of pairs.
 * For constructors it is strange that the `undef` value comes before the keys. It is not too late to introduce `Array{Int}((3,5,7), undef))`, for example. Or even `Array{Int}(Base.CartesianIndices((3,5,7)), undef))`. Basically the keys should be in the first slot...
 * Constructors including copy-constructor should probably require opt-in, perhaps required if can be returned by `similar`, `empty`, but not in general (e.g. a `PairDictionary` cannot be copy-constructed, it's a dictionary wrapper instead).
 * A surface interface for updates like https://github.com/JuliaLang/julia/pull/31367
 * Improved printing - replace `=>` with `│` and colummar indentation, don't calculate length (beyond some cutoff) if it is `SizeUnknown`.
 * Soon we will have the concept of "ordered" indices/sets (sort-based dictionaries and B-trees). We can probably formalize an interface around a trait here. Certain operations like slicing out an interval or performing a sort-merge co-iteration for `merge` become feasible.