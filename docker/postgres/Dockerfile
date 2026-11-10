FROM postgres@sha256:aa6cb33cf4c19c765cefcf48d96176258800870a9a1e930ad126200f9d825139 AS patched

# Refresh Alpine packages from the official repositories so fixed security
# releases are included even before the upstream PostgreSQL image is rebuilt.
# The upstream gosu binary was built with a vulnerable Go toolchain; the
# official Alpine su-exec package provides the same user-switching behavior
# used by docker-entrypoint.sh without embedding a stale Go runtime.
RUN set -eux; \
    apk upgrade --no-cache; \
    apk add --no-cache su-exec; \
    rm -f /usr/local/bin/su-exec; \
    printf '#!/bin/sh\nexec /sbin/su-exec "$@"\n' > /usr/local/bin/gosu; \
    chmod 0755 /usr/local/bin/gosu; \
    gosu postgres id | grep -q 'uid=70(postgres)'

# Copy the official image's patched, merged filesystem into a clean stage.
# This drops the vulnerable gosu binary from the underlying upstream layer,
# rather than merely hiding it behind a replacement in a later image layer.
FROM scratch
COPY --from=patched / /

ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    LANG="en_US.utf8" \
    PG_MAJOR="16" \
    PG_VERSION="16.15" \
    PG_SHA256="c1575341fa7bd40f5274ea465b34390f4dc64cdd0770af327005caaeb9f6b7ed" \
    DOCKER_PG_LLVM_DEPS="llvm21-dev clang21" \
    PGDATA="/var/lib/postgresql/data"

VOLUME /var/lib/postgresql/data
EXPOSE 5432
STOPSIGNAL SIGINT
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["postgres"]
