# Owncast for Railway: the official image, pinned by version and digest, plus a
# small start script. Bump the FROM line (tag and digest) to update; deployers
# get Railway's "update available" notice when this lands on main.
FROM owncast/owncast:0.3.0@sha256:0f35b568b1098d2badbde2dbf3c73a902009c95eb687c647edea04d6da079a78

# No packages are installed: the start script only uses the image's busybox
# (sh, wget, sha256sum), so the build is a few seconds and needs no mirror.
COPY start.sh /usr/local/bin/railway-start
# Owncast looks for ./ffmpeg in its working directory (/app) before $PATH.
# The wrapper caps ffmpeg's encoder threads to the container's CPU limit.
COPY ffmpeg-wrapper.sh /app/ffmpeg
RUN chmod 755 /usr/local/bin/railway-start /app/ffmpeg \
 && sh -n /usr/local/bin/railway-start && sh -n /app/ffmpeg

WORKDIR /app
EXPOSE 8080 1935
ENTRYPOINT ["/usr/local/bin/railway-start"]
