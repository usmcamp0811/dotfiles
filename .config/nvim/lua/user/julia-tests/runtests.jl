using Test

sites =
    ["http://boardgamegeek.com", "http://lidovky.cz", "http://lemonde.fr", "http://sony.jp"]
site = first(sites)


charsets = ["UTF-8", "windows-1250", "UTF-8", "Shift_JIS"]

@testset "My Project Tests!!!" begin
    @testset "fail_fail_fail" begin
        @test 0 ≠ 1
        @test "a" ≠ "a"
    end
    
    @testset "length test" begin 
        @test length(charsets) != 44
        @test length(charsets) == 44
    end
    @testset "not group b test" begin 
        @test length(charsets) == 44
    end
    @testset "Group B" begin 
        @testset "something good" begin 
            @test 3.14 ≈ π 
            @test 2.31 == 2.31
        end
    end
end



