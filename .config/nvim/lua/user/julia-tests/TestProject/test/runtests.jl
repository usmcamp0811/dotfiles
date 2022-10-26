using Test
using TestProject

sites =
    ["http://boardgamegeek.com", "http://lidovky.cz", "http://lemonde.fr", "http://sony.jp"]
site = first(sites)


charsets = ["UTF-8", "windows-1250", "UTF-8", "Shift_JIS"]

@testset "My Project Tests!!!" begin
    @testset "Correct Project" begin
        @test TestProject.greet() == "Hello World!"
    end
    @testset "fail_fail_fail" begin
        # @test 1 ≠ 1
        @test "a" != "b"
    end
    
    @testset "length test" begin 
        @test length(charsets) != 44
        @test length(charsets) != 44
    end
    @testset "not group b test" begin 
        # @test length(charsets) != 4
        @test length(charsets) == 4
    end
    @testset "Group B" begin 
        @testset "something good" begin 
            # @test 3.14 ≈ π
            @test 3.31 == 2.31
        end
        @testset "Group C" begin 
            @testset "something bad" begin 
                @test 3.14 ≈ π
                # @test 2.31 == 2.31
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



