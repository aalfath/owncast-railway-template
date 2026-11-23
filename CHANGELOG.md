# Changelog

## 0.3.0 (2026-11-23)

First release of this template.

- Owncast 0.3.0, official image `owncast/owncast:0.3.0@sha256:0f35b568b1098d2badbde2dbf3c73a902009c95eb687c647edea04d6da079a78`.
- Generated admin password and stream key replace upstream's `abc123` defaults before the server starts listening.
- Server URL set to the Railway domain on first boot.
- ffmpeg encoder threads capped to the container's CPU limit.
- All state on the `/app/data` volume. Health check `/api/status`. RTMP over a Railway TCP proxy on port 1935.
