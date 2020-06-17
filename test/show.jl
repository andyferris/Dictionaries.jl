@testset "show" begin
    function show_str(d)
        io = IOBuffer()
        io_context = IOContext(io, :limit => true, :displaysize => (10, 20))
        show(io_context, MIME"text/plain"(), d)
        return String(take!(io))
   end

   @test show_str(Indices()) == "0-element Indices{Any}"
   @test show_str(Indices(1:3)) == "3-element Indices{Int64}\n 1\n 2\n 3"
   @test show_str(Indices(1:100)) == "100-element Indices{Int64}\n 1\n 2\n 3\n ⋮\n 99\n 100"
   @test show_str(filterview(iseven, Indices(1:100))) == "Greater than 6-element FilteredIndices{Int64,Indices{Int64},typeof(iseven)}\n 2\n 4\n 6\n ⋮\n 98\n 100"
   @test show_str(Indices([collect(1:100)])) == "1-element Indices{Array{Int64,1}}\n [1, 2, 3, 4, 5, 6,…"
   @test show_str(Indices([collect(1:(100+i)) for i in 1:100])) == "100-element Indices{Array{Int64,1}}\n [1, 2, 3, 4, 5, 6,…\n [1, 2, 3, 4, 5, 6,…\n [1, 2, 3, 4, 5, 6,…\n ⋮\n [1, 2, 3, 4, 5, 6,…\n [1, 2, 3, 4, 5, 6,…"

   @test show_str(Dictionary()) == "0-element Dictionary{Any,Any}"
   @test show_str(Dictionary(1:3,101:103)) == "3-element Dictionary{Int64,Int64}\n 1 │ 101\n 2 │ 102\n 3 │ 103"
   @test show_str(Dictionary(1:100,101:200)) == "100-element Dictionary{Int64,Int64}\n   1 │ 101\n   2 │ 102\n   3 │ 103\n   ⋮ │ ⋮\n  99 │ 199\n 100 │ 200"
   @test show_str(Dictionary(collect(1:100), collect(101:200))) == "100-element Dictionary{Int64,Int64}\n   1 │ 101\n   2 │ 102\n   3 │ 103\n   ⋮ │ ⋮\n  99 │ 199\n 100 │ 200"
   @test show_str(Dictionary([collect(1:100+i) for i in 1:100],[collect(101:200+i) for i in 1:100])) == "100-element Dictionary{Array{Int64,1},Array{Int64,1}}\n [1, 2, … │ [101, 1…\n [1, 2, … │ [101, 1…\n [1, 2, … │ [101, 1…\n        ⋮ │ ⋮\n [1, 2, … │ [101, 1…\n [1, 2, … │ [101, 1…"
end