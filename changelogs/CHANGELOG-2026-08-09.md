# Changelog — 2026-08-09

## SearXNG self-hosted metasearch (new)
- Self-hosted search front-end. Metasearch, not an independent index — results
  come from upstream engines (Brave, DuckDuckGo, Mojeek, Startpage) minus
  tracking. Google engine left **disabled**: it CAPTCHAs/blocks server-IP
  requests, so leaving it on only yields dead results and error icons.
- New unprivileged Debian LXC, VLAN 25, **10.0.25.X** (see IP correction
  below). Docker Compose: `searxng-core` + `searxng-valkey` (valkey:9-alpine).
- Config from the current `searxng/searxng` main-repo template. The old
  `searxng-docker` repo is deprecated — despite blog posts claiming SearXNG was
  archived, the main repo is live (verified current build tags).
- `--nameserver 1.1.1.1` set at `pct create` time — recurring VLAN 25 external
  DNS gotcha, and SearXNG makes heavy outbound DNS to reach engines.
- `settings.yml`: `limiter: true` (needs valkey, wired), `image_proxy: true`,
  `formats: [html, json]`. json is required for the Open WebUI tie-in below.
- Secret via `SEARXNG_SECRET` (openssl rand -hex 32), driven from `.env`, not
  committed.

## Open WebUI + local LLM agent (new)
- Ollama on the Win11 3060 box does GPU inference; Open WebUI in a homelab LXC
  is the agent/UI layer. Open WebUI needs no GPU — it orchestrates and calls
  Ollama's API.
- Ollama bound LAN-wide (`OLLAMA_HOST=0.0.0.0`, firewall allow TCP 11434) so
  the WebUI LXC can reach it.
- Models for the 12GB card: `qwen2.5:14b` (primary, ~9GB, native tool-calling),
  `llama3.1:8b` (fast agent loops). 20B-class avoided on purpose: at Q4 it fills
  12GB and starves the KV cache, which specifically breaks agent tool-call
  chains that need context headroom.
- Open WebUI LXC: Debian, VLAN 25, **10.0.25.X**, Docker,
  `OLLAMA_BASE_URL=http://<3060-box>:11434`.
- Web search wired to SearXNG: Admin > Settings > Web Search > SearXNG, query
  URL `http://10.0.25.X:8080/search?q=<query>`. Works because SearXNG has
  json enabled. Agent grounds answers in the self-hosted search.

## Caddy + DNS
- Two hosts added to the `*.example.internal` block as `@host` + `handle` matchers,
  NOT standalone site blocks. A standalone block has no `tls { dns cloudflare }`
  directive, so it would attempt an ACME challenge it can't complete internally
  and fail to get a cert. Inside the wildcard block it inherits the wildcard.
    - `search.example.internal` -> 10.0.25.X:8080
    - `ai.example.internal`     -> 10.0.25.X:3000
  Placed before the final `handle { respond "nothing here" 404 }`.
- DNS: no change. The MikroTik `.*\.spills\.beer` regexp already resolves both
  to Caddy (10.0.25.X).
- Remote: no change. 10.0.25.X/24 is already advertised over Netbird and
  Caddy's 443 is reachable off-network, so both hosts work remotely on reload.

## Correction: IP assignments (earlier this session)
- Earlier I assigned SearXNG 10.0.25.X and Open WebUI 10.0.25.X. Both
  are **already in use** per docs/tls/Caddyfile: .13 is ntfy (LXC 108), .14 is
  kanboard. Reassigned to .15 and .16. All config here reflects the fix.

## Open items
- 3060 box VLAN **unverified** — confirm `curl http://<3060-box>:11434/api/tags`
  succeeds from the Open WebUI LXC before wiring web search. Timeout = Windows
  firewall or a VLAN forward rule, not Ollama.
- Brave Search API (independent index behind SearXNG) not done — free scraping
  engines only for now.
- .15 and .16 not yet added to infrastructure-ip-table.md.
- Open WebUI depends on the 3060 box being powered on for inference; UI persists
  but chats fail if the box is off (e.g. rebooted for gaming).
