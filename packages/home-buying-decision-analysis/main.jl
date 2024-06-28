using CSV
using DataFrames

function parse_home_ratings(file_path::String)
    # Read the CSV file into a DataFrame
    df = CSV.read(file_path, DataFrame)

    # Define a mapping from rating text to numeric values
    rating_map = Dict(
        "0 - Really Disagree" => 0,
        "1 - Mostly Disagree" => 1,
        "2 - Slightly Disagree" => 2,
        "3 - Neither Agree or Disagree" => 3,
        "4 - Slightly Agree" => 4,
        "5 - Mostly Agree" => 5,
        "6 - Really Agree" => 6
    )

    # Iterate through the columns and replace rating text with numeric values
    for col in names(df)
        if startswith(col, "This house") || startswith(col, "There was") || startswith(col, "The Server") || startswith(col, "There is") || startswith(col, "You can") || startswith(col, "I really") || startswith(col, "The home") || startswith(col, "There was a room")
            df[!, col] = map(x -> rating_map[x], df[!, col])
        end
    end

    return df
end

# Example usage
file_path = "Home Rating Form (test) (responses).csv"
df = parse_home_ratings(file_path)
println(df)
