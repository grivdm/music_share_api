# Music Share API 🎵

[![Ruby](https://img.shields.io/badge/Ruby-3.2-red.svg)](https://www.ruby-lang.org/)
[![Rails](https://img.shields.io/badge/Rails-8.0-red.svg)](https://rubyonrails.org/)
[![CI](https://github.com/grivdm/music_share_api/actions/workflows/ci.yml/badge.svg)](https://github.com/grivdm/music_share_api/actions/workflows/ci.yml)



REST API for music link conversion between streaming platforms.


## Features
-  Convert between Spotify, Deezer, YouTube Music
-  Docker & Kamal deployment
-  PostgreSQL caching

## Platforms
| Platform | Status | ISRC Search |
|----------|--------|-------------|
| Spotify | ✅ | ✅ |
| Deezer | ✅ | ✅ |
| YouTube Music | ✅ | ❌ |

## Usage
```http
POST /api/v1/convert
{"url": "https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT"}

Response:
{
  "track": {"title": "Song", "artist": "Artist"},
  "links": {"spotify": "...", "deezer": "..."}
}
```

## Development
```bash
git clone repo && cd music_share_api
bundle install
cp .env.example .env  # Configure API keys
rails db:setup && rails server
```

