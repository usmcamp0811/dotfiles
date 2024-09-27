using PyCall
using DataFrames, Missings
@pyimport redfin
@pyimport homeharvest as hh

Redfin = redfin.Redfin()

function get_properties(city::String; listing_type::String="for_sale", past_days::Int=30, min_price::Int=300_000, max_price::Int=560_000)

    # Fetch properties
    properties = hh.scrape_property(
        location=city,
        listing_type=listing_type,
        past_days=past_days
    )

    # Define the columns you want to select

    # Define the columns you want to select
    selected_columns = ["city", "days_on_mls", "full_baths", "full_street_line", 
                        "beds", "list_date", "list_price", "lot_sqft", "mls", 
                        "price_per_sqft", "primary_photo", "property_url", "sqft",
                        "year_built", "zip_code"]

    # Convert Python NAType to Julia `missing` and convert to correct types
    df = DataFrame(properties.values, Symbol.(properties.columns))

    # Convert fields while allowing for `missing` values
    df[!,"list_price"] = allowmissing(df[!,"list_price"])  # Allow missing
    df[!,"list_price"] = map(x -> isnothing(x) ? missing : convert(Int, x), df[!,"list_price"])
    df = filter(x -> x["list_price"] in min_price:max_price, df)
    return df
end

louisville = get_properties("Louisville, KY"; max_price=600_000)
stlouis = get_properties("St. Louis, MO"; max_price=600_000)
baltimore = get_properties("Baltimore, MD"; max_price=600_000)
philly = get_properties("Philadelphia, PA"; max_price=600_000)
lancaster = get_properties("Lancaster, PA"; max_price=600_000)
washington = get_properties("Washington, DC"; max_price=600_000)
  # past_days=30,  # sold in last 30 days - listed in last 30 days if (for_sale, for_rent)

  # date_from="2023-05-01", # alternative to past_days
  # date_to="2023-05-28",
  # foreclosure=True
  # mls_only=True,  # only fetch MLS listings

city = "Louisville, KY"
min_price = 300_000
max_price = 600_000
min_walk_score = 70
listing_type = "for_sale"
past_days = 180
parse.(Int, String.(louisville[!,"list_price"]))

louisville[1,"list_price"].attribute
