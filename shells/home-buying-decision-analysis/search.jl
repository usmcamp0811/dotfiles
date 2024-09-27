using PyCall
@pyimport redfin

Redfin = redfin.Redfin()

function get_properties(city::String, min_price::Int, max_price::Int, min_walk_score::Int)
    r = redfin.Redfin()
    # Search properties based on city and price range
    results = r.search(city, min_price=min_price, max_price=max_price)
    
    # Extract properties from the search result's payload sections
    properties = []
    for section in results["payload"]["sections"]
        if haskey(section, "rows")
            for row in section["rows"]
                if haskey(row, "walk_score") && row["walk_score"] >= min_walk_score
                    push!(properties, row)
                end
            end
        end
    end

    return properties
end

# Example usage
city = "Louisville, KY"
min_price = 300_000
max_price = 600_000
min_walk_score = 70

properties = get_properties(city, min_price, max_price, min_walk_score)
println(properties)

