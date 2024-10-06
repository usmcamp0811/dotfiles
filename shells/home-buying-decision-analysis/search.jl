using PyCall
using DataFrames, Missings, CSV
@pyimport redfin
@pyimport homeharvest as hh

Redfin = redfin.Redfin()

# Function to convert PyObjects to appropriate Julia types
function coerce_column(column)
    return [isa(v, PyObject) ? (string(v) == "<NA>" ? missing : convert(PyAny, v)) : v for v in column]
end

# Apply coercion to all columns of the DataFrame
function coerce_dataframe(df::DataFrame)
    for col in names(df)
        df[!, col] = coerce_column(df[!, col])
    end
    return df
end

function get_properties(city::String; listing_type::String="for_sale", past_days::Int=30,
min_price::Int=300_000, max_price::Int=560_000)

    # Fetch properties
    properties = hh.scrape_property(
        location=city,
        listing_type=listing_type,
        past_days=past_days
    )

    # Convert Python NAType to Julia `missing` and convert to correct types
    df = DataFrame(properties.values, Symbol.(properties.columns))
    df = coerce_dataframe(df)

    # Convert fields while allowing for `missing` values
    df = filter(x -> x["list_price"] in min_price:max_price, df)
    return df
end


function get_properties(cities::Array; listing_type::String="for_sale", past_days::Int=30,
min_price::Int=300_000, max_price::Int=560_000, save_csv::Bool=true, csv_name::String="properties.csv")
  all_properties = DataFrame()  # Initialize an empty DataFrame to collect all properties

  # Check if file exists to avoid writing the header multiple times
  file_exists = isfile(csv_name)

  for city in cities
    properties = get_properties(city; max_price=max_price)  # Get properties for the city

    if save_csv
      # Write the header only if the file doesn't exist yet
      CSV.write(csv_name, properties, append=file_exists, writeheader=!file_exists)
      file_exists = true  # Set file exists to true after first write
    else
      all_properties = vcat(all_properties, properties)  # Concatenate properties DataFrame if not saving
      to CSV
    end
  end

  if !save_csv
    return all_properties  # Return the collected properties if not saving to CSV
  end
end


cities = ["Pittsburgh, PA", "Louisville, KY", "Chattanooga, TN"]
cities = ["Louisville, KY", "St. Louis, MO", "Baltimore, MD",
          "Indianapolis, IN", "Philadelphia, PA", "Lancaster, PA",
          "Washington, DC", "Seattle, WA", "Denver, CO", "Portsmouth, VA",
          "Cleveland, OH", "Pittsburgh, PA", "Milwaukee, WI",
          "Buffalo, NY", "New Orleans, LA", "Minneapolis, MN",
          "Cincinnati, OH", "Kansas City, MO", "Richmond, VA",
          "Omaha, NE", "Providence, RI", "Rochester, NY",
          "Columbus, OH", "Detroit, MI", "Madison, WI",
          "Chattanooga, TN", "Salt Lake City, UT", "Worcester, MA",
          "Grand Rapids, MI", "Albany, NY", "Hartford, CT",
          "Knoxville, TN", "Dayton, OH", "Durham, NC",
          "Asheville, NC", "Greenville, SC", "Boise, ID",
          "Spokane, WA", "Fort Wayne, IN", "Toledo, OH",
          "Little Rock, AR", "Birmingham, AL", "Springfield, MA",
          "Augusta, GA", "Mobile, AL", "Tucson, AZ",
          "Fayetteville, AR", "Des Moines, IA", "Syracuse, NY",
          "Winston-Salem, NC", "Memphis, TN"]


properties = get_properties(cities; max_price=600_000, csv_name="properties.csv")


using OpenStreetMapX, HTTP, JSON

function get_nearby_places(address::String; walking_distance_minutes::Int=15, place_type::String="grocery")
    # Approximate walking distance based on time (15 minutes ≈ 1.2 km)
    distance_meters = walking_distance_minutes * 80  # Rough estimate of walking speed: 80 meters per minute

    # Geocode the address using OpenStreetMap Nominatim API
    query_url = "https://nominatim.openstreetmap.org/search?q=$(replace(address, ' ' =>
    '+'))&format=json&limit=1"
    response = HTTP.get(query_url)
    location = JSON.parse(String(response.body))[1]
    lat, lon = location["lat"], location["lon"]

    # Set Overpass API query depending on the place type
    query_type = place_type == "restaurant" ? "amenity=\"restaurant\"" : "shop=\"supermarket\""

    # Overpass API query to find places within the defined walking distance
    overpass_url = """
    [out:json];
    node[$query_type](around:$distance_meters,$lat,$lon);
    out body;
    """
    overpass_url = replace(overpass_url, "\$lat" => lat, "\$lon" => lon, "\$distance_meters" =>
    string(distance_meters))

    # Send the query
    overpass_api_url = "http://overpass-api.de/api/interpreter"
    overpass_response = HTTP.post(overpass_api_url, [], overpass_url)
    places = JSON.parse(String(overpass_response.body))["elements"]

    # Return place details (name, lat, lon)
    nearby_places = [(place["tags"]["name"], place["lat"], place["lon"]) for place in places if
    haskey(place["tags"], "name")]
    return nearby_places
end

# Example usage
address = "1513 Morton Ave, Louisville, KY 40204"
address = "4166 Orchid St, Colorado Springs, CO 80917"
address = "817 Yuma St, Colorado Springs, CO 80909"
address = "2449 Ranch Ln, Colorado Springs, CO 80918"
address = "2315 W 46th Ave, Denver, CO 80211"
address = "1343 Mirrillion Heights, Colorado Springs, CO 80904"
address = "253 Marcus St, Walla Walla, WA 99362"
address = "5501 S Fawcett Ave, Tacoma, WA 98408"
address = "4504 SE 65th Ave, Portland, OR 97206"
address = "580 5th St, Lakeport, CA 95453"
address = "211 Beech Street, Trinidad, CO 81082"
address = "1232 Juniata St, Pittsburgh, PA 15233"
address = "117 Vernon Ave, Louisville, KY 40206"
address = "98 Ruth Street Pittsburgh, PA 15211"
address = "3914 Howley Street Pittsburgh, PA 15224"
address = "3423 Denny Street Pittsburgh, PA 15201"
address = "1206 Linden Place Pittsburgh, PA 15212"
address = "5415 Black Street Pittsburgh, PA 15206"
address = "257 38th Street Pittsburgh, PA 15201"
address = "1612 Buena Vista Street Pittsburgh, PA 15212"
address = "1304 Debree Ave, Norfolk, VA 23517"
grocery_stores = get_nearby_places(address, walking_distance_minutes=15, place_type="grocery")
restaurants = get_nearby_places(address, walking_distance_minutes=15, place_type="restaurant")

using HTTP

url = "https://tripadvisor16.p.rapidapi.com/api/v1/restaurant/searchRestaurants?locationId=304554"

headers = Dict(
    "x-rapidapi-key" => fastapikey,
    "x-rapidapi-host" => "tripadvisor16.p.rapidapi.com"
)

response = HTTP.get(url, headers)
data = String(response.body)

println(data)
