#!/bin/bash

# Optional debug mode - only enable when needed
if [[ "$DEBUG" == "true" ]]; then
  set -x
fi

# Set error handling
set -euo pipefail

NEOFORGE_VERSION=21.1.180
SERVER_VERSION=4.0

cd /data || { echo "Failed to cd to /data"; exit 1; }

# EULA acceptance check - clearer logic
if [[ "$EULA" != "true" ]]; then
  echo "You must accept the EULA to install. Set EULA=true"
  exit 99
fi

echo "eula=true" > eula.txt

# Function to download and extract server files
download_and_extract() {
  if [[ ! -f "Server-Files-$SERVER_VERSION.zip" ]]; then
    echo "Downloading and extracting server files..."
    rm -fr config defaultconfigs kubejs mods packmenu Server-Files-* neoforge*

    curl -fLo "Server-Files-$SERVER_VERSION.zip" "https://mediafilez.forgecdn.net/files/6664/93/ServerFiles-$SERVER_VERSION.zip" || { 
      echo "Failed to download server files"; exit 9; 
    }

    unzip -u -o "Server-Files-$SERVER_VERSION.zip" -d /data
    DIR_TEST="ServerFiles-$SERVER_VERSION"
    if [[ $(find . -maxdepth 1 -type d | wc -l) -gt 1 ]]; then
      cd "$DIR_TEST" || { echo "Failed to cd to $DIR_TEST"; exit 1; }
      # More secure permissions instead of 777
      find . -type d -exec chmod 755 {} +
      find . -type f -exec chmod 644 {} +
      mv -f * /data
      cd /data || exit 1
      rm -fr "$DIR_TEST"
    fi

    curl -fLo neoforge-${NEOFORGE_VERSION}-installer.jar \
      "https://maven.neoforged.net/releases/net/neoforged/neoforge/$NEOFORGE_VERSION/neoforge-$NEOFORGE_VERSION-installer.jar" || { 
      echo "Failed to download neoforge installer"; exit 9; 
    }
    
    java -jar neoforge-${NEOFORGE_VERSION}-installer.jar --installServer
  fi
}

# Function to update server properties efficiently
update_server_properties() {
  local prop="$1"
  local val="$2"
  sed -i "s/^${prop}=.*/${prop}=${val}/" server.properties
}

# Function to add users to JSON files with better error handling
add_user_to_json() {
  local user_list="$1"
  local json_file="$2"
  local extra_fields="$3"
  local file_type="$4"

  [[ -z "$user_list" ]] && return 0

  IFS=',' read -ra USERS <<< "$user_list"
  local uuids_to_fetch=()
  local usernames=()

  # Validate usernames first
  for raw_username in "${USERS[@]}"; do
    username=$(echo "$raw_username" | xargs)
    if [[ -z "$username" ]] || ! [[ "$username" =~ ^[a-zA-Z0-9_]{3,16}$ ]]; then
      echo "$file_type: Invalid username '$username'. Skipping..."
      continue
    fi
    usernames+=("$username")
  done

  # Fetch UUIDs for valid usernames
  for username in "${usernames[@]}"; do
    if jq -e ".[] | select(.name == \"$username\")" "$json_file" > /dev/null 2>&1; then
      echo "$file_type: $username is already in $json_file. Skipping..."
      continue
    fi

    UUID=$(curl -s --max-time 10 "https://playerdb.co/api/player/minecraft/$username" | jq -r '.data.player.id' 2>/dev/null)
    if [[ "$UUID" != "null" && -n "$UUID" ]]; then
      echo "$file_type: Adding $username ($UUID)."
      jq ". += [{\"uuid\": \"$UUID\", \"name\": \"$username\"$extra_fields}]" "$json_file" > tmp.json && mv tmp.json "$json_file"
    else
      echo "$file_type: Failed to fetch UUID for $username."
    fi
  done
}

# Download and extract server files
download_and_extract

# Update JVM options more efficiently
if [[ -n "${JVM_OPTS:-}" ]]; then
  sed -i '/^-Xm[sx]/d' user_jvm_args.txt
  printf '%s\n' $JVM_OPTS >> user_jvm_args.txt
fi

# Batch update server properties
{
  [[ -n "${MOTD:-}" ]] && echo "motd=$MOTD"
  [[ -n "${ENABLE_WHITELIST:-}" ]] && echo "white-list=$ENABLE_WHITELIST"
  [[ -n "${ALLOW_FLIGHT:-}" ]] && echo "allow-flight=$ALLOW_FLIGHT"
  [[ -n "${MAX_PLAYERS:-}" ]] && echo "max-players=$MAX_PLAYERS"
  [[ -n "${ONLINE_MODE:-}" ]] && echo "online-mode=$ONLINE_MODE"
  echo "server-port=25565"
} | while IFS='=' read -r prop val; do
  update_server_properties "$prop" "$val"
done

# Initialize JSON files if not present
[[ ! -f whitelist.json ]] && echo "[]" > whitelist.json
[[ ! -f ops.json ]] && echo "[]" > ops.json

# Add users to the whitelist and ops
add_user_to_json "${WHITELIST_USERS:-}" whitelist.json "" "Whitelist"
add_user_to_json "${OP_USERS:-}" ops.json ", \"level\": 4, \"bypassesPlayerLimit\": false" "Ops"

# Set proper permissions and run
chmod 755 run.sh
exec ./run.sh
