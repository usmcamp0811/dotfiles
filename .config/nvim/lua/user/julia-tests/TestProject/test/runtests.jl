using Test
using TestProject

sites =
    ["http://boardgamegeek.com", "http://lidovky.cz", "http://lemonde.fr", "http://sony.jp"]
site = first(sites)


charsets = ["UTF-8", "windows-1250", "UTF-8", "Shift_JIS"]

@testset "Main" begin
    @testset "Child of Main 1" begin
        @test TestProject.greet() == "Hello World!"
    end
    @testset "Child of Main 2" begin
        # @test 1 ≠ 1
        @test "a" != "b"
    end
    
    @testset "Child of Main 3" begin 
        @test length(charsets) != 44
        @test length(charsets) != 44
    end
    @testset "Child of Main 4" begin 
        # @test length(charsets) != 4
        @test length(charsets) == 4
    end
    @testset "Child of Main 5" begin 
        @testset "Child of Main 5a" begin 
            # @test 3.14 ≈ π
            @test 3.31 == 2.31
        end
        @testset "Child of Main 5b" begin 
            @testset "Child of Main 5b1" begin 
                # @test 3.14 ≈ π
                @test 2.31 == 2.31
            end
            # @testset "fail good" begin 
            #     # @test 3.14 ≈ π
            #     @test 2.31 == 2.31
            # end
        end
        # @testset "fail good" begin 
        #     # @test 3.14 ≈ π
        #     @test 2.31 == 2.31
        # end
    end
end


