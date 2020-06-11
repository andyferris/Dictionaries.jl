@testset "foreach" begin
    i = Indices([1,2,3,4,5])

    tmp = Ref(0)
    foreach(x -> tmp[] += x, i)
    @test tmp[] == 15

    tmp = Ref(0)
    foreach((x,y) -> tmp[] += x + y, i, i)
    @test tmp[] == 30

    tmp = Ref(0)
    foreach((x,y) -> tmp[] += x + y, i, copy(i))
    @test tmp[] == 30

    tmp = Ref(0)
    foreach((x,y,z) -> tmp[] += x + y + z, i, i, i)
    @test tmp[] == 45

    tmp = Ref(0)
    foreach((x,y,z) -> tmp[] += x + y + z, i, i, copy(i))
    @test tmp[] == 45

    d = i .+ 1

    tmp = Ref(0)
    foreach(x -> tmp[] += x, d)
    @test tmp[] == 20

    tmp = Ref(0)
    foreach((x,y) -> tmp[] += x + y, d, d)
    @test tmp[] == 40

    tmp = Ref(0)
    foreach((x,y) -> tmp[] += x + y, d, copy(d))
    @test tmp[] == 40

    tmp = Ref(0)
    foreach((x,y,z) -> tmp[] += x + y + z, d, d, d)
    @test tmp[] == 60

    tmp = Ref(0)
    foreach((x,y,z) -> tmp[] += x + y + z, d, d, copy(d))
    @test tmp[] == 60
end