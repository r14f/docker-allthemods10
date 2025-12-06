# syntax=docker/dockerfile:1

# Use a more specific and stable base image
FROM eclipse-temurin:21-jdk-alpine

# Set metadata
LABEL maintainer="r14f" \
      description="All The Mods 10 Minecraft Server" \
      version="5.3.1"

# Create non-root user for security
RUN addgroup -g 1000 -S minecraft && \
    adduser -u 1000 -G minecraft -h /data -s /bin/bash -D minecraft

# Update package lists (optional with --no-cache, but good for fresh index)
RUN apk update

# Install packages separately for better caching in unRAID
RUN apk add --no-cache curl
RUN apk add --no-cache unzip  
RUN apk add --no-cache jq
RUN apk add --no-cache ca-certificates

# Clean up in final step (mostly for temp files; --no-cache handles apk cache)
RUN rm -rf /tmp/* /var/tmp/*

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
