using CSV
using DataFrames
using HTTP
using JSON
using Gumbo

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

    # Rename columns to more user-friendly names (lowercase and no spaces)
    new_names = Dict(
        "User ID" => "user_id",
        "User display name" => "user_display_name",
        "Timestamp" => "timestamp",
        "This house was big enough for the two of us and all the animals" => "house_size",
        "This house has enough yard space for the dogs." => "yard_space",
        "There was a room for Matt's office." => "office_room",
        "The Server Rack has a place it can go." => "server_rack_space",
        "There is enough countertop space in the kitchen." => "countertop_space",
        "This house has an induction range" => "induction_range",
        "There is a garage or covered parking space to put the Mazda." => "parking",
        "You can walk to a grocery store to get food to cook." => "walkable_grocery",
        "You can easily walk to restaurants and bars." => "walkable_restaurants_bars",
        "I really like the esthetic of the home." => "aesthetic_appeal",
        "I really like the flooring in the home." => "flooring_appeal",
        "There is pantry space to store our food." => "pantry_space",
        "The home has sufficient Air Conditioning" => "air_conditioning",
        "There is a fireplace and I like how it looks." => "fireplace_appeal",
        "There is a place to keep and use the grill." => "grill_space",
        "The house is move in ready." => "move_in_ready"
    )

    rename!(df, new_names)

    # Iterate through the columns and replace rating text with numeric values
    for col in names(df)
        if col ∈ keys(new_names)
            df[!, col] = map(x -> rating_map[x], df[!, col])
        end
    end

    return df
end





function scrape_property_details(address::String)
    # Clean up the address for URL encoding
    encoded_address = HTTP.URIs.escapeuri(address)

    # Construct the URL for Zillow (example)
    zillow_url = "https://www.zillow.com/homes/$encoded_address"

    # Send the HTTP GET request to Zillow
    response = HTTP.get(zillow_url)

    # Check if the request was successful
    if response.status == 200
        # Parse HTML response
        html = String(response.body)
        page = Gumbo.parsehtml(html)

        # Find all elements that potentially contain property prices
        price_elements = eachmatch(
            node -> isa(node, Gumbo.TextNode) && contains(string(node), "\$"),
            page.root
        )

        # Extract the first found price (adjust this logic based on actual HTML structure)
        if !isempty(price_elements)
            property_price = strip(string(price_elements[1]))
            return property_price
        else
            return "Price not found"
        end
    else
        println("Error: Unable to fetch property details.")
        return ""
    end
end

# Example usage
address = "572 N Plum St, Lancaster, PA 17602"
details = scrape_property_details(address)
println(details)
# Example usage
file_path = "/config/packages/home-buying-decision-analysis/form.csv"
df = parse_home_ratings(file_path)
println(df)
