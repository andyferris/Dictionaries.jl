@testset "show" begin
    function show_str(d)
        io = IOBuffer()
        io_context = IOContext(io, :limit => true, :displaysize => (10, 20))
        show(io_context, MIME"text/plain"(), d)
        return String(take!(io))
    end

    if VERSION < v"1.6-"
        @test show_str(Indices{Int64}()) == "0-element Indices{Int64}"
        @test show_str(Indices{Int64}(1:3)) == "3-element Indices{Int64}\n 1\n 2\n 3"
        @test show_str(Indices{Int64}(1:100)) == "100-element Indices{Int64}\n 1\n 2\n 3\n ⋮\n 99\n 100"
        @test show_str(filterview(iseven, Indices{Int64}(1:100))) == "Greater than 6-element FilteredIndices{Int64,Indices{Int64},typeof(iseven)}\n 2\n 4\n 6\n ⋮\n 98\n 100"
        if Int === Int64
            @test show_str(Indices{Vector{Int64}}([collect(1:100)])) == "1-element Indices{Array{Int64,1}}\n [1, 2, 3, 4, 5, 6,…"
            @test show_str(Indices{Vector{Int64}}([collect(1:(100+i)) for i in 1:100])) == "100-element Indices{Array{Int64,1}}\n [1, 2, 3, 4, 5, 6,…\n [1, 2, 3, 4, 5, 6,…\n [1, 2, 3, 4, 5, 6,…\n ⋮\n [1, 2, 3, 4, 5, 6,…\n [1, 2, 3, 4, 5, 6,…"
        else
            @test show_str(Indices{Vector{Int64}}([collect(1:100)])) == "1-element Indices{Array{Int64,1}}\n Int64[1, 2, 3, 4, …"
            @test show_str(Indices{Vector{Int64}}([collect(1:(100+i)) for i in 1:100])) == "100-element Indices{Array{Int64,1}}\n Int64[1, 2, 3, 4, …\n Int64[1, 2, 3, 4, …\n Int64[1, 2, 3, 4, …\n ⋮\n Int64[1, 2, 3, 4, …\n Int64[1, 2, 3, 4, …"
        end

        @test show_str(Dictionary{Int64,Int64}()) == "0-element Dictionary{Int64,Int64}"
        @test show_str(Dictionary{Int64,Int64}(1:3,101:103)) == "3-element Dictionary{Int64,Int64}\n 1 │ 101\n 2 │ 102\n 3 │ 103"
        @test show_str(Dictionary{Int64,Int64}(1:100,101:200)) == "100-element Dictionary{Int64,Int64}\n   1 │ 101\n   2 │ 102\n   3 │ 103\n   ⋮ │ ⋮\n  99 │ 199\n 100 │ 200"
        @test show_str(filterview(iseven, Dictionary{Int64,Int64}(1:100,101:200))) == "Greater than 6-element FilteredDictionary{Int64,Int64,Dictionary{Int64,Int64},typeof(iseven)}\n   2 │ 102\n   4 │ 104\n   6 │ 106\n   ⋮ │ ⋮\n  98 │ 198\n 100 │ 200"
        @test show_str(Dictionary{Int64,Int64}(collect(1:100), collect(101:200))) == "100-element Dictionary{Int64,Int64}\n   1 │ 101\n   2 │ 102\n   3 │ 103\n   ⋮ │ ⋮\n  99 │ 199\n 100 │ 200"
        if Int === Int64
            @test show_str(Dictionary{Vector{Int64},Vector{Int64}}([collect(1:100+i) for i in 1:100],[collect(101:200+i) for i in 1:100])) == "100-element Dictionary{Array{Int64,1},Array{Int64,1}}\n [1, 2, … │ [101, 1…\n [1, 2, … │ [101, 1…\n [1, 2, … │ [101, 1…\n        ⋮ │ ⋮\n [1, 2, … │ [101, 1…\n [1, 2, … │ [101, 1…"
        else
            @test show_str(Dictionary{Vector{Int64},Vector{Int64}}([collect(1:100+i) for i in 1:100],[collect(101:200+i) for i in 1:100])) == "100-element Dictionary{Array{Int64,1},Array{Int64,1}}\n Int64[1… │ Int64[1…\n Int64[1… │ Int64[1…\n Int64[1… │ Int64[1…\n        ⋮ │ ⋮\n Int64[1… │ Int64[1…\n Int64[1… │ Int64[1…"
        end
    else
        @test show_str(Indices{Int64}()) == "0-element Indices{Int64, Vector{Int64}}"
        @test show_str(Indices{Int64}(1:3)) == "3-element Indices{Int64, UnitRange{Int64}}\n 1\n 2\n 3"
        @test show_str(Indices{Int64}(1:100)) == "100-element Indices{Int64, UnitRange{Int64}}\n 1\n 2\n 3\n ⋮\n 99\n 100"
        @test show_str(filterview(iseven, Indices{Int64}(1:100))) == "Greater than 6-element FilteredIndices{Int64, Indices{Int64, UnitRange{Int64}}, typeof(iseven)}\n 2\n 4\n 6\n ⋮\n 98\n 100"
        if Int === Int64
            @test show_str(Indices{Vector{Int64}}([collect(1:100)])) == "1-element Indices{Vector{Int64}, Vector{Vector{Int64}}}\n [1, 2, 3, 4, 5, 6,…"
            @test show_str(Indices{Vector{Int64}}([collect(1:(100+i)) for i in 1:100])) == "100-element Indices{Vector{Int64}, Vector{Vector{Int64}}}\n [1, 2, 3, 4, 5, 6,…\n [1, 2, 3, 4, 5, 6,…\n [1, 2, 3, 4, 5, 6,…\n ⋮\n [1, 2, 3, 4, 5, 6,…\n [1, 2, 3, 4, 5, 6,…"
        else
            @test show_str(Indices{Vector{Int64}}([collect(1:100)])) == "1-element Indices{Vector{Int64}}\n Int64[1, 2, 3, 4, …"
            @test show_str(Indices{Vector{Int64}}([collect(1:(100+i)) for i in 1:100])) == "100-element Indices{Vector{Int64}}\n Int64[1, 2, 3, 4, …\n Int64[1, 2, 3, 4, …\n Int64[1, 2, 3, 4, …\n ⋮\n Int64[1, 2, 3, 4, …\n Int64[1, 2, 3, 4, …"
        end

        @test show_str(Dictionary{Int64,Int64}()) == "0-element Dictionary{Int64, Int64}"
        @test show_str(Dictionary{Int64,Int64}(1:3,101:103)) == "3-element Dictionary{Int64, Int64}\n 1 │ 101\n 2 │ 102\n 3 │ 103"
        @test show_str(Dictionary{Int64,Int64}(1:100,101:200)) == "100-element Dictionary{Int64, Int64}\n   1 │ 101\n   2 │ 102\n   3 │ 103\n   ⋮ │ ⋮\n  99 │ 199\n 100 │ 200"
        @test show_str(filterview(iseven, Dictionary{Int64,Int64}(1:100,101:200))) == "Greater than 6-element FilteredDictionary{Int64, Int64, Dictionary{Int64, Int64}, typeof(iseven)}\n   2 │ 102\n   4 │ 104\n   6 │ 106\n   ⋮ │ ⋮\n  98 │ 198\n 100 │ 200"
        @test show_str(Dictionary{Int64,Int64}(collect(1:100), collect(101:200))) == "100-element Dictionary{Int64, Int64}\n   1 │ 101\n   2 │ 102\n   3 │ 103\n   ⋮ │ ⋮\n  99 │ 199\n 100 │ 200"
        if Int === Int64
            @test show_str(Dictionary{Vector{Int64},Vector{Int64}}([collect(1:100+i) for i in 1:100],[collect(101:200+i) for i in 1:100])) == "100-element Dictionary{Vector{Int64}, Vector{Int64}}\n [1, 2, … │ [101, 1…\n [1, 2, … │ [101, 1…\n [1, 2, … │ [101, 1…\n        ⋮ │ ⋮\n [1, 2, … │ [101, 1…\n [1, 2, … │ [101, 1…"
        else
            @test show_str(Dictionary{Vector{Int64},Vector{Int64}}([collect(1:100+i) for i in 1:100],[collect(101:200+i) for i in 1:100])) == "100-element Dictionary{Vector{Int64}, Vector{Int64}}\n Int64[1… │ Int64[1…\n Int64[1… │ Int64[1…\n Int64[1… │ Int64[1…\n        ⋮ │ ⋮\n Int64[1… │ Int64[1…\n Int64[1… │ Int64[1…"
        end
    end
    
end
