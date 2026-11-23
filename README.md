[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/owncast-1?utm_medium=integration&utm_source=button&utm_campaign=owncast)

# Owncast on Railway

One-click [Owncast](https://owncast.online) for [Railway](https://railway.com): a self-hosted live video streaming and chat server, an independent alternative to Twitch or YouTube Live.

This template deploys **Owncast 0.3.0**, the official image `owncast/owncast:0.3.0`, pinned by digest (`sha256:0f35b568b1098d2badbde2dbf3c73a902009c95eb687c647edea04d6da079a78`).

## What you get

One service, `Owncast`, built from this repo:

| Piece | What it is |
|---|---|
| Public domain (HTTPS) on port 8080 | Web player, chat, admin at `/admin`, HLS video |
| TCP proxy to port 1935 | RTMP ingest for OBS, Streamlabs, ffmpeg and other encoders |
| Volume at `/app/data` | SQLite database (settings, chat, users), emoji, logo, logs, HLS segments |
| Health check `/api/status` | Restart policy `ON_FAILURE` |

## Variables

| Variable | Default | What it does |
|---|---|---|
| `OWNCAST_ADMIN_PASSWORD` | `${{secret(24)}}` | Password for the `admin` user at `/admin` |
| `OWNCAST_STREAM_KEY` | `${{secret(24)}}` | Stream key your encoder sends |
| `PORT` | `8080` | Web port (the domain points here) |

There's nothing to fill in. Upstream Owncast starts with the public default password and stream key `abc123`. This template replaces both with generated secrets before the server starts listening. Each value is applied once per change of its Railway variable. If you change the password or key later in Owncast's own admin, the next deploy keeps your change. To reset it, change the Railway variable.

## After deploying

1. Open the service's public URL. You should see the offline player and chat.
2. Go to `/admin` and sign in as `admin`, with the password from the `OWNCAST_ADMIN_PASSWORD` variable.
3. In your encoder (OBS: Settings → Stream → Service "Custom…"), set:
   - **Server:** `rtmp://<TCP proxy domain>:<TCP proxy port>/live`. Railway shows them under Settings → Networking → TCP Proxy, and the deploy log prints the full URL. Don't use the RTMP address shown inside Owncast's admin: it's derived from the web domain, which carries only HTTPS.
   - **Stream key:** the `OWNCAST_STREAM_KEY` variable.
4. Start streaming. Within a few seconds the admin shows the stream as online and the public page plays it.

## Resources

Owncast transcodes the incoming stream with ffmpeg. With its default single 1200 kbps output, a 720p30 input used about 0.31 GB RAM and a fraction of one vCPU in our test at a 0.5 GB / 1 vCPU limit. Adding output qualities or higher resolutions under Admin → Video needs more CPU and RAM. Owncast doesn't limit ffmpeg's threads by itself, so this repo's `ffmpeg` wrapper caps the encoder at the container's CPU limit (override with `OWNCAST_FFMPEG_THREADS`).

## Updates

Railway notifies everyone who deployed this template when a new version lands on `main` of this repo, and you choose when to apply it. Read [CHANGELOG.md](CHANGELOG.md) first, since breaking changes are listed at the top of each entry. Your settings, chat history and stream keys are on the volume and survive updates. Owncast's own upgrade notes are in its [releases](https://github.com/owncast/owncast/releases).

## Files

- `Dockerfile`: the pinned official image plus the two scripts below. No packages are installed.
- `start.sh`: binds to `$PORT` and RTMP 1935, applies the generated password, stream key and server URL, and passes Owncast's exit code through so Railway restarts it after a crash.
- `ffmpeg-wrapper.sh`: caps the live transcode's encoder threads to the container's CPUs.

Owncast is MIT-licensed by the Owncast project. This repo only packages it.
