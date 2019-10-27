# Maps.jl

*An alternative interface for dictionaries (or associative **maps**) in Julia*

The high-level goal of this package is to define a new interface for dictionary and set structures which is convenient for functional data manipulation - including operations such as non-scalar indexing, mapping, filtering, reducing, and so-on.

## Motivation

While Julia comes with built-in `AbstractDict` and `AbstractSet` supertypes, the interfaces for these are not as well established or generic as for `AbstractArray`, and dictionaries implement less of the common data manipulation operations compared to arrays - such as broadcasting, `map`, `reduce`, and `filter` (and their mutating counterparts).

In this package we aim to devise a cohesive interface for abstract dictionaries or associative maps, having the common supertype `AbstractMap`. A large part of this is working with indices (of arbitrary type) as well as convenient and efficient iteration of the containers. A secondary goal is to make dictionary manipulation more closely resemble array manipulation, to make it easier for users.

There are multiple areas of the design space that we can explore for dictionary structures that might make them more convenient for various use-cases. Here we are focused on data manipulation - taking in input datasets and processing it with dictionaries as a part of a larger dataflow. A simple of example of where usablility of an interface might differ, Julia's inbuild `Dict` will iterate key-value pairs, whereas `AbstractMap` chooses to iterate values by default. An example in the data space where this convenient is starting with a dictionary mapping people's names to their age, called `ages` say, and calculating the `mean` age. With `AbstractMap`s (as with `AbstractArray`s) we can just use `mean(ages)`.