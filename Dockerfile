# The demo server image, ghcr.io/orca-gateway/demo-server. Built by
# .github/workflows/engine-release.yml from a context holding only the Linux
# binary, demo-server-linux-x64 (bun build --compile examples/server/index.ts).
FROM gcr.io/distroless/cc-debian12
WORKDIR /app
COPY demo-server-linux-x64 /app/demo-server
USER nonroot
EXPOSE 8080
ENV PORT=8080
CMD ["/app/demo-server"]
