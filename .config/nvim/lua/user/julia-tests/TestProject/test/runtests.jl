using Test
using TestProject

@testset "My Test Project Tests" begin
  @testset "Hello World Test" begin
    @test TestProject.greet() == "Hello World!"
  end
  @testset "Failed Test" begin
    @test "a" != "b"
  end

  @testset "Passing Tests" begin
    @test length(charsets) != 44
    @test length(charsets) != 44
  end
  @testset "Group of Tests" begin
    @testset "First Nested Test Set" begin
      # @test 3.14 ≈ π
      @test 2.31 == 2.31
    end
    @testset "Next Nested Test Set" begin
      @test 2.31 == 2.31
      @testset "More Nesting" begin
        @test 3.14 ≈ π
        @test 2.31 == 2.31
        @testset "Tests in a Loop" begin
          for i ∈ 1:20
            @test rand() < rand()
          end
        end
      end
    end
  end
end



