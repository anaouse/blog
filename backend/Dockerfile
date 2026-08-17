# syntax=docker/dockerfile:1

# ---- stage 1: build ----
FROM golang:1.25-alpine AS build
WORKDIR /app
COPY backend/go.mod backend/go.sum ./
RUN go mod download
COPY backend/ ./
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -o /blog-backend .

# ---- stage 2: run ----
FROM alpine:3.20
RUN adduser -D -u 10001 appuser
USER appuser
COPY --from=build /blog-backend /blog-backend
EXPOSE 6713
ENTRYPOINT ["/blog-backend"]
