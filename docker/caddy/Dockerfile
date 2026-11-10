# syntax=docker/dockerfile:1.7

FROM caddy@sha256:d26fbc8a56ed8c3c1534f5573162d148ad3ed41732665da8526eb181fac0b728 AS build
WORKDIR /src
RUN git init . \
    && git remote add origin https://github.com/caddyserver/caddy.git \
    && git fetch --depth=1 origin 0d98caea58f794f88e709b1bef2880996a471bca \
    && git checkout --detach FETCH_HEAD

# Keep the released Caddy source while taking the upstream dependency fixes
# already present in current Caddy development: Smallstep no longer pulls the
# vulnerable go-jose/v3, x/net is patched, and x/crypto includes its advisory
# fix. The builder is the Docker Official Caddy builder with Go 1.27.3.
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go mod edit \
      -require=github.com/smallstep/certificates@v0.30.3-0.20261105213751-6d5a251fbe01 \
      -require=go.step.sm/crypto@v0.92.0 \
      -require=golang.org/x/net@v0.62.0 \
      -require=golang.org/x/crypto@v0.58.1-0.20261009181718-2f1f834330b2 \
    && go mod tidy \
    && go build -buildvcs=false -trimpath -ldflags='-s -w -X github.com/caddyserver/caddy/v2.CustomVersion=v2.11.9' -o /src/caddy ./cmd/caddy

FROM caddy@sha256:0bbb055bda6793c999bde78b1b5ce3e89f829fb031af2cf50056ea1246559fee AS updated-runtime
RUN apk upgrade --no-cache
COPY --from=build /src/caddy /usr/bin/caddy

# Flatten the official runtime filesystem so replaced vulnerable binaries and
# packages are absent from the resulting image layers, not only hidden.
FROM scratch
COPY --from=updated-runtime / /
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    XDG_CONFIG_HOME="/config" \
    XDG_DATA_HOME="/data" \
    CADDY_VERSION="v2.11.9"
WORKDIR /srv
EXPOSE 2019 443/tcp 443/udp 80/tcp
CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
