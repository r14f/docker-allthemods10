# syntax=docker/dockerfile:1

# Use a more specific and stable base image
FROM openjdk:21-jdk-slim

# Set metadata
LABEL maintainer="r14f" \
      description="All The Mods 10 Minecraft Server" \
      version="4.14"

# Create non-root user for security
RUN groupadd -r minecraft --gid=1000 && \
    useradd -r -g minecraft --uid=1000 --home-dir=/data --shell=/bin/bash minecraft

# Update package lists
RUN apt-get update

# Install packages separately for better caching in unRAID
RUN apt-get install -y --no-install-recommends curl
RUN apt-get install -y --no-install-recommends unzip  
RUN apt-get install -y --no-install-recommends jq
RUN apt-get install -y --no-install-recommends ca-certificates

# Clean up in final step
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Set working directory and create with proper ownership
WORKDIR /data
RUN chown minecraft:minecraft /data

# Copy launch script with proper permissions
COPY --chown=minecraft:minecraft launch.sh /data/launch.sh
RUN chmod +x /data/launch.sh

# Only set essential environment variables that affect container behavior
ENV EULA=false

# Expose Minecraft port
EXPOSE 25565

# Create volume for persistent data
VOLUME ["/data"]

# Switch to non-root user
USER minecraft

# Use exec form for better signal handling
ENTRYPOINT ["/data/launch.sh"]
