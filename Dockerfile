FROM oven/bun:1.2.5 AS builder
WORKDIR /app
COPY package.json bun.lockb* ./
RUN bun install --frozen-lockfile
COPY . .
RUN bun build src/server.ts --compile --outfile orcagateway

FROM gcr.io/distroless/cc-debian12
WORKDIR /app
COPY --from=builder /app/orcagateway .
USER nonroot
EXPOSE 8080
CMD ["./orcagateway"]
