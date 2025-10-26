#!/bin/bash

# Optimized for unRAID Docker containers
# Disable debug mode by default (unRAID handles logging differently)
if [[ "${DEBUG:-false}" == "true" ]]; then
  set -x
fi

# Set error handling but be more permissive for unRAID
set -eo pipefail

NEOFORGE_VERSION=21.1.203
SERVER_VERSION=4.14

# Ensure we're in the data directory (mounted volume in unRAID)
cd /data || { echo "Failed to access /data volume"; exit 1; }

# EULA acceptance check
if [[ "${EULA:-false}" != "true" ]]; then
  echo "=========================================="
  echo "You must accept the EULA to continue."
  echo "Set EULA=true in your unRAID template"
  echo "=========================================="
  exit 99
fi

echo "eula=true" > eula.txt

# Function to download and extract server files
download_and_extract() {
  if [[ ! -f "Server-Files-$SERVER_VERSION.zip" ]]; then
    echo "Downloading and extracting server files..."
    
    # Clean up old files but preserve user data
    rm -rf config defaultconfigs kubejs mods packmenu Server-Files-* neoforge*
    
    # Download with unRAID-friendly settings
    echo "Downloading server files (this may take a while)..."
    curl -fL --connect-timeout 30 --max-time 600 \
      -o "Server-Files-$SERVER_VERSION.zip" \
      "https://mediafilez.forgecdn.net/files/7121/795/ServerFiles-$SERVER_VERSION.zip" || {
      echo "Failed to download server files. Check your internet connection."
      exit 9
    }
    
    echo "Extracting server files..."
    unzip -q -u -o "Server-Files-$SERVER_VERSION.zip" -d /data
    
    DIR_TEST="ServerFiles-$SERVER_VERSION"
    if [[ -d "$DIR_TEST" ]]; then
      cd "$DIR_TEST" || { echo "Failed to access extracted directory"; exit 1; }
      
      # Set permissions appropriate for unRAID (less restrictive)
      find . -type d -exec chmod 755 {} + 2>/dev/null || true
      find . -type f -exec chmod 644 {} + 2>/dev/null || true
      
      # Move files and clean up
      cp -rf * /data/ 2>/dev/null || mv * /data/
      cd /data || exit 1
      rm -rf "$DIR_TEST"
    fi

    echo "Downloading NeoForge installer..."
    curl -fL --connect-timeout 30 --max-time 300 \
      -o "neoforge-${NEOFORGE_VERSION}-installer.jar" \
      "https://maven.neoforged.net/releases/net/neoforged/neoforge/$NEOFORGE_VERSION/neoforge-$NEOFORGE_VERSION-installer.jar" || {
      echo "Failed to download NeoForge installer"
      exit 9
    }
    
    echo "Installing NeoForge server..."
    java -jar "neoforge-${NEOFORGE_VERSION}-installer.jar" --installServer
    
    echo "Server installation completed successfully!"
  else
    echo "Server files already exist, skipping download..."
  fi
}

# Function to update server properties (unRAID template friendly)
update_server_properties() {
  local prop="$1"
  local val="$2"
  
  # Create server.properties if it doesn't exist
  [[ ! -f server.properties ]] && touch server.properties
  
  # Update or add property
  if grep -q "^${prop}=" server.properties; then
    sed -i "s/^${prop}=.*/${prop}=${val}/" server.properties
  else
    echo "${prop}=${val}" >> server.properties
  fi
}

# Function to add users to JSON files (unRAID optimized)
add_user_to_json() {
  local user_list="$1"
  local json_file="$2"
  local extra_fields="$3"
  local file_type="$4"

  [[ -z "$user_list" ]] && return 0

  # Initialize JSON file if it doesn't exist
  [[ ! -f "$json_file" ]] && echo "[]" > "$json_file"

  IFS=',' read -ra USERS <<< "$user_list"
  
  for raw_username in "${USERS[@]}"; do
    username=$(echo "$raw_username" | xargs)
    
    # Skip empty usernames
    [[ -z "$username" ]] && continue
    
    # Basic username validation
    if ! [[ "$username" =~ ^[a-zA-Z0-9_]{3,16}$ ]]; then
      echo "$file_type: Invalid username '$username'. Skipping..."
      continue
    fi

    # Check if user already exists
    if jq -e ".[] | select(.name == \"$username\")" "$json_file" >/dev/null 2>&1; then
      echo "$file_type: $username already exists. Skipping..."
      continue
    fi

    # Fetch UUID with timeout suitable for unRAID
    echo "$file_type: Adding $username..."
    UUID=$(curl -s --connect-timeout 10 --max-time 15 \
      "https://playerdb.co/api/player/minecraft/$username" 2>/dev/null | \
      jq -r '.data.player.id' 2>/dev/null)
    
    if [[ "$UUID" != "null" && -n "$UUID" && "$UUID" != "" ]]; then
      echo "$file_type: Successfully added $username ($UUID)"
      jq ". += [{\"uuid\": \"$UUID\", \"name\": \"$username\"$extra_fields}]" \
        "$json_file" > "${json_file}.tmp" && mv "${json_file}.tmp" "$json_file"
    else
      echo "$file_type: Warning - Could not fetch UUID for $username (player may not exist)"
    fi
  done
}

# Main execution starts here
echo "=========================================="
echo "All The Mods 10 Server Setup for unRAID"
echo "=========================================="

# Download and extract server files
download_and_extract

# Handle JVM options for unRAID (memory management is crucial)
if [[ -n "${JVM_OPTS:-}" ]]; then
  echo "Applying custom JVM options: $JVM_OPTS"
  # Remove existing memory settings
  sed -i '/^-Xm[sx]/d' user_jvm_args.txt 2>/dev/null || touch user_jvm_args.txt
  # Add new JVM options
  echo "$JVM_OPTS" | tr ' ' '\n' >> user_jvm_args.txt
else
  echo "Using default JVM options"
fi

# Update server properties with unRAID template values
echo "Configuring server properties..."

# Core server settings
update_server_properties "server-port" "25565"
update_server_properties "server-ip" ""

# Apply unRAID template variables
[[ -n "${MOTD:-}" ]] && update_server_properties "motd" "$MOTD"
[[ -n "${MAX_PLAYERS:-}" ]] && update_server_properties "max-players" "$MAX_PLAYERS"
[[ -n "${ONLINE_MODE:-}" ]] && update_server_properties "online-mode" "$ONLINE_MODE"
[[ -n "${ALLOW_FLIGHT:-}" ]] && update_server_properties "allow-flight" "$ALLOW_FLIGHT"
[[ -n "${ENABLE_WHITELIST:-}" ]] && update_server_properties "white-list" "$ENABLE_WHITELIST"
[[ -n "${DIFFICULTY:-}" ]] && update_server_properties "difficulty" "$DIFFICULTY"
[[ -n "${GAMEMODE:-}" ]] && update_server_properties "gamemode" "$GAMEMODE"
[[ -n "${PVP:-}" ]] && update_server_properties "pvp" "$PVP"

# Initialize JSON files
echo "Setting up user permissions..."
[[ ! -f whitelist.json ]] && echo "[]" > whitelist.json
[[ ! -f ops.json ]] && echo "[]" > ops.json

# Add users from unRAID template
add_user_to_json "${WHITELIST_USERS:-}" "whitelist.json" "" "Whitelist"
add_user_to_json "${OP_USERS:-}" "ops.json" ", \"level\": 4, \"bypassesPlayerLimit\": false" "Ops"

# Ensure run script is executable
chmod +x run.sh 2>/dev/null || {
  echo "Warning: Could not make run.sh executable"
}

echo "=========================================="
echo "Starting Minecraft server..."
echo "Server will be available on port 25565"
echo "Check unRAID Docker logs for server output"
echo "=========================================="

# Use exec for proper signal handling in unRAID
exec ./run.sh
