{pkgs}:
pkgs.writeShellScriptBin "check-vault-path" ''
  full_path="$1"

  # Check for PKI engines
  if [[ "$full_path" == *"/issue/"* ]]; then
    engine_path=$(echo "$full_path" | awk -F '/issue/' '{print $1}')
    role=$(echo "$full_path" | awk -F '/issue/' '{print $2}')

    if vault read -format=json "$engine_path/roles/$role" > /dev/null 2>&1; then
      exit 0
    fi
  else
    # Try listing the parent path
    parent_path=$(dirname "$full_path")
    if [ "$parent_path" == "." ]; then
      parent_path=""
    fi

    output=$(vault list -format=json "$parent_path" 2>&1)
    if [[ "$output" == *"$full_path"* || "$output" == *"listing is not allowed"* ]]; then
      exit 0
    elif vault kv get $1 > /dev/null 2>&1; then
      exit 0
    elif vault kv list $1/ > /dev/null 2>&1; then
      exit 0
    fi
  fi

  exit 1
''
