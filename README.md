# Dictionaries.jl

*An alternative interface for dictionaries in Julia*

[![Build Status](https://travis-ci.org/andyferris/Dictionaries.jl.svg?branch=master)](https://travis-ci.org/andyferris/Dictionaries.jl)
[![Codecov](https://codecov.io/gh/andyferris/Dictionaries.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/andyferris/Dictionaries.jl)

The high-level goal of this package is to define a new interface for dictionary and set structures which is convenient for functional data manipulation - including operations such as non-scalar indexing, mapping, filtering, reducing, and so-on.

## Motivation

While Julia comes with built-in `AbstractDict` and `AbstractSet` supertypes, the interfaces for these are not as well established or generic as for `AbstractArray`, and dictionaries implement less of the common data manipulation operations compared to arrays - such as broadcasting, `map`, `reduce`, and `filter` (and their mutating counterparts).

In this package we aim to devise a cohesive interface for abstract dictionaries (or associative maps), having the common supertype `AbstractDictionary`. A large part of this is working with indices (of arbitrary type) as well as convenient and efficient iteration of the containers. A second goal is to make dictionary manipulation more closely resemble array manipulation, to make it easier for users.

There are multiple areas of the design space that we can explore for dictionary structures that might make them more convenient for various use-cases. Here we are focused on data manipulation - taking in input datasets and processing it with dictionaries as a part of a larger dataflow. A simple of example of where usablility of an interface might differ, Julia's in-built `AbstractDict` will iterate key-value pairs, whereas `AbstractDictionary` chooses to iterate values by default. An example in the data space where this convenient is starting with a dictionary mapping people's names to their age, called `ages` say, and calculating the `mean` age. With `AbstractDictionary`s (as with `AbstractArray`s) we can just use `mean(ages)`.

## Types, interfaces and traits

### `AbstractDictionary`

The common supertype to this package is `AbstractDictionary{I, T}`, which models an indexable container. To implement a simple `AbstractDictionary` all you need to implement is:

 * `getindex(::AbstractDictionary{I, T}, ::I) --> T`
 * `keys(::AbstractDictionary{I, T}) --> AbstractIndices{I}`

Built upon just these, a range of useful functionality is provided, generally consistent with `AbstractArray`. **NOTE:** When iterating an `AbstractDictionary`, keep in mind that only the values are iterated (like `AbstractArray`) and not key-value pairs (like `AbstractDict`). This provides a more consistent usage of `map`, `filter`, `reduce`, `broadcast`, and the functions in *SplitApplyCombine.jl* and *Indexing.jl*.

### `AbstractIndices`

Indexable containers in Julia have `keys`, which form a "set" in the mathematic sense of a collection of distinct elements. The `keys` of an `AbstractDictionary{I, T}` must have type `AbstractIndices{I}`. These form a set because no two elements in an `AbstractIndices` can be `isequal`. To implement a simple index type, you need to provide:

 * The `iterate` protocol, returning unique values of type `I`.
 * `in`, such that `in(i, indices)` implies there is an element of `indices` which `isequal` to `i`.

Indices themselves are also dictionaries (much like the indices of `AbstractArray`s are also `AbstractArray`s), and we have the subtyping relationship `AbstractDictionary{I} <: AbstractDictionary{I, I}`. Indexing an `AbstractIndex` is always *idempotent*, such that `index[i] === i`. The `keys` function is also idempotent: `keys(indices::AbstractIndices) === indices` (and therefore `keys(keys(dict::AbstractDictionary)) === keys(dict)`). While indexing into indices may seem unintuitive or obtuse at first, this is quite a natural mathematical formulation that supports the indexing behavior below and the entire `AbstractDictionary` interface. (Dictionaries that iterate values is key to allowing this formulation).

### Non-scalar indexing

Indexing an `AbstractDictionary` follows the interface provided by the *Indexing.jl* package. Since the indices of a dictionary may be of arbitrary type (including being a container such as an array or a dictionary), a function distinct to `getindex` is required to indicate non-scalar indexing.

The expression `dict3 = getindices(dict1, dict2)` follows the following simple rules:

 * The output indices match the indexer, such that `issetequal(keys(dict3), keys(dict2))`.
 * The values of `dict3` come directly from `dict1`, such that `dict3[i] === dict1[dict2[i]]` for all `i in keys(dict2)`.

Non-scalar indexing is simplified such that it is essentially `getindices(dict1, dict2) = map(getindex, dict1, dict2)`. Note also that `getindices(dict, keys(dict))` has the same keys and values as `dict`, and is synonymous with `getindices(dict, :)`.

These rules match those for `AbstractArray`, including offset arrays. The `view` function works similarly, as does the `setindices!` function from *Indexing.jl* (see mutation, below).

### Mutation

Many dictionary types support mutation of the *values* of the elements. To support mutation, an `AbstractDictionary` should implement:

 * `ismutable(::AbstractDictionary)` (returning `true`)
 * `setindex!(dict::AbstractDictionary{I, T}, ::T, ::I}` (returning `dict`)

The `ismutable` function is a trait-function that indicate whether an `AbstractDictionary` supports `setindex!`.

Because the idempotency property of `AbstractIndices`, indices always have immutable values - but indices can be inserted or deleted (see below).

### Insertion and deletion

If arbitrary indices can be added to or removed from an `AbstractDictionary`, one needs to implement:

 * `isinsertable(::AbstractDictionary)` (returning `true`)
 * `insert!(dict::AbstractDictionary{I, T}, ::T, ::I}` (returning `dict`)
 * `delete!(dict::AbstractDictionary{I, T}, ::I}` (returning `dict`)

The `insert!` and `delete!` always create or remove indices. Calling `insert!` when an index already exists will throw an error, as will attempting to `delete!` an index that does not exist. The function `set!` is provided as an "upsert" (update or insert) operation. Similarly, `unset!` function can be used to ensure a given index does not exist. The `get!` function works as in `Base`.

**NOTE**: `setindex!` can *never* create new indices, unlike with Julia's `AbstractDict` (and many other programming languages!). Always use `set!` to perform an "upsert" operation. This change may seem inconvenient at first, but it is similar to `AbstractArray` and how Julia differs from MATLAB in requiring one to explicitly `push!` to the end of a vector (a much less bug-prone pattern).

Sometimes one wishes to manipulate `AbstractIndices` directly, either to create the keys for a new container or as a part of set logic. To do so, implement:

 * `insert!(indices, i)` - add new index `i` to `indices` (will error if index exists)
 * `delete!(indices, i)` - remove an existing index `i` from `indices` (will error if index does not exist).

The `set!` and `unset!` functions behave as expected, as do `union!`, `intersect!`, `setdiff!` and `symdiff!`. Since indices iterate values, the `filter!` function can programmatically trim back a set of indices.

### Tokens

Make it fast! The concept is similar to `eachindex`, but a bit more generalized. Tokens can also optimize `set!`, `get!` and `unset!` stype operations. Work-in-progress.