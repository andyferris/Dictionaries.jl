# Each file of the form "bench_$(name).jl" in this directory is `include`d and
# its last statement is assumed to be a `BenchmarkGroup`.  This group is added
# to the top-level group `SUITE` with the `$name` extracted from the file name.

using BenchmarkTools
using DataFrames
using Statistics

const SUITE = BenchmarkGroup()
for file in sort(readdir(@__DIR__))
    if startswith(file, "bench_") && endswith(file, ".jl")
        SUITE[chop(file, head = length("bench_"), tail = length(".jl"))] =
            include(file)
    end
end

tune!(SUITE)
results = run(SUITE; verbose=true, seconds=1)

result_df = DataFrame()
for (group, group_results) in pairs(results)
    for (n, n_results) in pairs(group_results)
        for (benchmark, benchmark_results) in pairs(n_results)
            for (datastructure, datastructure_result) in pairs(benchmark_results)
                push!(result_df, (; group, benchmark, n=parse(Int, n), datastructure, time_mean=mean(datastructure_result.times), time_std = std(datastructure_result.times)))
            end
        end
    end
end

result_df