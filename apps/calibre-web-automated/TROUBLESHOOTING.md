# Troubleshooting & lessons learned

Everything that broke while getting CWA + Kobo sync working (2026-09-15), how
each failure was diagnosed, and the exact fix. Read top to bottom when sync
misbehaves — the failure modes are layered: transport → schema → auth handshake
→ sync state.

## Diagnosis toolbox

All of these were needed at some point. The Kobo shows only "Sync failed".

```bash
# Every request the device makes, with status codes (access log is enabled on
# the http://books.lan block in ../proxy/Caddyfile). Device IP shows as
# remote_ip; look for 192.168.0.x != this host.
docker logs caddy --since 30m 2>&1 | grep 'http.log.access' | python3 -c "
import json, sys
for line in sys.stdin:
    try: d = json.loads(line)
    except Exception: continue
    r = d.get('request', {})
    print(r.get('remote_ip'), r.get('method'), r.get('uri')[:80], '->', d.get('status'), d.get('size'))"

# App-side sync/metadata/checksum activity
docker logs calibre-web-automated --since 30m 2>&1 | grep -iE 'kobo|checksum|error'

# Replay the device flow yourself with the real token (no device needed).
# Token lives in app.db -> remote_auth_token (token_type=1):
TOKEN=$(docker exec calibre-web-automated python3 -c "
import sqlite3; print(sqlite3.connect('/config/app.db')\
  .execute('SELECT auth_token FROM remote_auth_token WHERE token_type=1 LIMIT 1').fetchone()[0])")
curl -s http://books.lan/kobo/$TOKEN/v1/initialization        # must be 200
curl -s http://books.lan/kobo/$TOKEN/v1/library/sync | jq length   # books offered
```

Healthy sync sequence (from caddy access log): `openid-configuration` →
`oauth/authorize` (302) → `oauth/token` → `v1/library/sync` (200) → per-book
`v1/library/<uuid>/metadata` → `download/...`.

## Problem 1: device can't connect at all (TLS)

**Symptom**: sync fails, zero `/kobo` requests in caddy/CWA logs.

**Cause**: Kobo firmware validates TLS strictly and **cannot trust Caddy's
internal CA** (and `.lan` can't get a public cert). Every handshake dies
before reaching the server.

**Fix**: `/kobo/*` is served over plain HTTP (`http://books.lan` block in
`../proxy/Caddyfile`); the device's `eReader.conf` endpoint must use `http://`.
Everything else on http redirects to https, so browser UX is unchanged.

## Problem 2: sync works sometimes — `no such table: book_format_checksums`

**Symptom**: intermittent sync failures; CWA logs spam
`ERROR ... Failed to store checksum for book N: (sqlite3.OperationalError) no
such table: book_format_checksums` on every kobo metadata request.

**Cause**: CWA v4.0.6 first-boot race — the checksum-backfill service runs
before the DB schema exists ("Database schema not ready after 30s, proceeding
anyway" in boot logs) and the table is never created. The exceptions abort
sync responses mid-stream. **The table lives in `metadata.db` (the library
DB), not app.db** — that cost us a wrong-DB detour.

**Fix** (idempotent):

```bash
docker exec calibre-web-automated python3 -c "
import sqlite3
c = sqlite3.connect('/calibre-library/metadata.db')
c.execute('''CREATE TABLE IF NOT EXISTS book_format_checksums (
    id INTEGER PRIMARY KEY,
    book INTEGER REFERENCES books(id) ON DELETE CASCADE,
    format TEXT, checksum TEXT(32), version TEXT, created TIMESTAMP)''')
c.execute('CREATE INDEX IF NOT EXISTS idx_checksum_lookup ON book_format_checksums(checksum, format)')
c.commit()"
docker compose restart calibre-web-automated
```

(`ON DELETE CASCADE` matters — CWA's init detects its absence and rebuilds.)

## Problem 3: init succeeds, then nothing — OIDC discovery (firmware 4.45+)

**Symptom**: caddy trace shows `v1/initialization` 200, then ~7-9 rapid
`/oauth/.well-known/openid-configuration` requests, then the device gives up.
`/v1/library/sync` is never requested. No errors anywhere.

**Cause**: firmware 4.45+ performs a real OIDC handshake before syncing.
CWA's `/oauth/<path>` catch-all answers the discovery request with a dummy
token blob, which the device can't parse as an OIDC document. Upstream bug:
[crocodilestick/Calibre-Web-Automated#1418](https://github.com/crocodilestick/Calibre-Web-Automated/issues/1418)
— **open as of 2026-09, no fixed release** (v4.0.6 is latest).

**Fix**: a three-endpoint OIDC shim in the `http://books.lan` block of
`../proxy/Caddyfile` — discovery document, `/oauth/authorize` redirect
(echoes `state`, custom `kobo://` scheme), `/oauth/token` + `/oauth/refresh`
with **10-year expiry** (short-lived dummy tokens re-break after 1h — that
gap cost the issue thread a week of confusion). Only safe with kobo store
proxying off (`config_kobo_proxy=0`, our default).

Gotcha from the same issue: if books arrive but the banner still says "sync
failed", it's the device's **notebook** sync — disable Settings → Accounts →
Synchronize Notebooks on the Kobo.

## Problem 4: sync succeeds but no books appear

**Cause**: by design. Two markers gate what the device is offered:

| Table (app.db) | Meaning |
|---|---|
| `kobo_synced_books` | books already delivered — never re-offered |
| `archived_book` | books the user deleted **on the device** — excluded from sync |

Deleting a book on the Kobo = archiving it server-side. CWA will silently
offer nothing new; there is no error to see.

**Fix — re-deliver books** (clear both markers, restart, re-sync):

```bash
docker exec calibre-web-automated python3 -c "
import sqlite3
c = sqlite3.connect('/config/app.db')
c.execute('DELETE FROM archived_book WHERE user_id=1')
c.execute('DELETE FROM kobo_synced_books WHERE user_id=1')
c.commit()"
docker compose restart calibre-web-automated
```

Verify with the toolbox: `sync | jq length` should list the library.
If the device still ignores the re-offers (nickel can keep local tombstones),
see Problem 5.

**Gotcha**: always clear **all** the user's `kobo_synced_books` rows. If any
remain (e.g. only the stuck books), CWA honors the device's sync token
("I have everything up to T") and the delta still excludes older books —
the fix looks applied but nothing is offered. With zero rows, CWA ignores
the token and re-offers the whole library; already-present books are
silently deduped by the device. Verify with a token-bearing request, not a
bare curl — a tokenless request skips the delta logic and always shows
everything:

```python
# x-kobo-synctoken header: base64 of {"version": "1-1-0", "data": {...}}
tok = {"version": "1-1-0", "data": {"raw_kobo_store_token": "",
    "books_last_modified": "2026-09-15T08:30:00+00:00",
    "books_last_created": "2026-09-15T08:30:00+00:00",
    "archive_last_modified": "2026-09-15T08:30:00+00:00",
    "reading_state_last_modified": "2026-09-15T08:30:00+00:00",
    "tags_last_modified": "2026-09-15T08:30:00+00:00"}}  # all keys required
```

## Problem 5: deleted books never come back, even after the Problem 4 cleanup

**Symptom**: markers cleared, sync shows `NewEntitlements` for them, but the
device never downloads them (no `download/...` requests in the caddy trace)
and CWA re-marks them synced.

**Cause**: nickel keeps a hidden tombstone for every book deleted on the
device. CWA sets `RevisionId`/`CrossRevisionId` = `books.uuid` (immutable), so
every re-offer matches the tombstone and is silently skipped. There is no
device-side UI to purge tombstones.

**Fix**: give the books new identities — regenerate `books.uuid` in
`metadata.db`, clear their `kobo_synced_books` rows, restart. Nickel sees
brand-new books and downloads them:

```bash
docker exec calibre-web-automated python3 -c "
import sqlite3, uuid
m = sqlite3.connect('/calibre-library/metadata.db')
def title_sort(t):
    return t or ''
m.create_function('title_sort', 1, title_sort)   # schema triggers need it
for bid in (2, 3, 4, 6):                          # stuck book ids
    m.execute('UPDATE books SET uuid=? WHERE id=?', (str(uuid.uuid4()), bid))
m.commit()
c = sqlite3.connect('/config/app.db')
c.execute('DELETE FROM kobo_synced_books WHERE user_id=1 AND book_id IN (2,3,4,6)')
c.commit()"
docker compose restart calibre-web-automated
```

Note: `metadata.db` triggers call Calibre's custom `title_sort()` SQL
function — register it on plain connections or every UPDATE fails with
`no such function: title_sort`.

Nuclear alternative: factory-reset the Kobo (wipes tombstones and everything
else). Prefer the uuid route.

## Mental model

- **Add books** → drop files into `/media/books/ingest` → CWA ingests +
  converts → **next device sync picks them up automatically**. That is the
  whole workflow; nothing else to trigger.
- **Delete on device** = tombstone locally + archive server-side; the book
  never comes back until the Problem 4 + Problem 5 cleanup.
- **Offered ≠ delivered**: CWA marks a book synced when it appears in a sync
  response, whether or not the device actually downloaded it. Check the caddy
  trace for `download/...` requests to tell the two apart.
- The device polls periodically on its own (init/analytics/deals hits in the
  log are normal noise; `3B` responses are CWA's empty store responses).

## Where state lives

| What | Where |
|---|---|
| Users, passwords, kobo sync markers, auth tokens | `~/calibre-web-automated/config/app.db` |
| Library (books + `metadata.db`) | `/media/books/library/` |
| Ingest drop folder (files removed after processing) | `/media/books/ingest/` |
| Kobo device endpoint config | on-device `/mnt/onboard/.kobo/Kobo/eReader.conf` → `[SyncService] api_endpoint=http://books.lan/kobo/<TOKEN>/` |
| Caddy vhost + OIDC shim | `../proxy/Caddyfile` |
| DNS record for `books.lan` | `../blocky/config.yaml` `customDNS.mapping` |
