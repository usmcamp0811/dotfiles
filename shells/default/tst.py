import pandas as pd
import os
import json
from tabulate import tabulate

# Your JSON string
file_path = os.path.expanduser('~/test.json')
# Load JSON into a dictionary
with open(file_path, 'r') as file:
    data_dict = json.load(file)

# Prepare a list of unique paths
all_paths = set()
for system_data in data_dict.values():
    for entry in system_data:
        if entry:
            all_paths.add(entry['path'])

# Sort paths for a cleaner output
all_paths = sorted(all_paths)

# Create a dictionary to hold the table data
table_data = {path: [] for path in all_paths}

# Fill in the table data
for system, system_data in data_dict.items():
    for path in all_paths:
        exists_value = None
        for entry in system_data:
            if entry and entry['path'] == path:
                exists_value = entry['exists']
                break
        if exists_value is not None:
            table_data[path].append('✓' if exists_value == 0 else 'X')
        else:
            table_data[path].append("-")  # or '-' if you want a placeholder

# Create a DataFrame
df = pd.DataFrame(table_data, index=data_dict.keys())

# Optionally, transpose the DataFrame to match your desired format
df = df.T

# Display or save the table
# Function to apply styles
def color_value(val):
    if val == 'X':
        return "\033[31mX\033[0m"  # Red
    elif val == '✓':
        return "\033[32m✓\033[0m"  # Green
    else:
        return val

# Color the values in DataFrame
df_colored = df.applymap(color_value)

# Convert DataFrame to a colored string
table_str = tabulate(df_colored, headers='keys', tablefmt='pretty', showindex=True)

# Print the colored table to terminal
print(table_str)
# df.to_csv('output.csv')  # Uncomment this line to save to a CSV file
