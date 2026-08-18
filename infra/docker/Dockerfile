FROM debian:bookworm-slim

RUN useradd --create-home --uid 10001 game
WORKDIR /app

# Export the Godot project to this location before building the image.
COPY build/server/coop-moba-survivor-server.x86_64 /app/game-server
RUN chmod +x /app/game-server

USER game
EXPOSE 27015/udp

ENTRYPOINT ["/app/game-server", "--server", "--port=27015"]
