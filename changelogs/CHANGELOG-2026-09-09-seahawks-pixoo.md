# 2026-09-09/10 — Seahawks Pixoo Dashboard Build

## Summary
Added a Seahawks game-day feature to the Living Room Pixoo 64 dashboard: live score/kickoff rotation page, a touchdown celebration animation, and a halftime animation.

## Home Assistant additions

**REST + template sensors** (`configuration.yaml`):
- `sensor.nfl_scoreboard_raw` — REST sensor polling `https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard` every 30s, storing the raw `events` array as an attribute.
- `sensor.seahawks_game` — template sensor parsing the raw scoreboard for the Seahawks game specifically. State is `pre` / `in` / `post` / `none`. Attributes: `seahawks_score`, `opponent_score`, `opponent_abbr`, `period`, `clock`, `kickoff`.

**Helper:**
- `input_number.seahawks_last_score` — tracks last known Seahawks score to detect touchdown deltas (created via Settings > Helpers UI).

**Automations** (`automations.yaml`, added via UI):
- `Pixoo - Seahawks Kickoff Reset` — fires on `sensor.seahawks_game` state `pre` -> `in`, zeroes `input_number.seahawks_last_score` so stale scores from a prior game don't cause a false touchdown trigger.
- `Pixoo - Seahawks Touchdown` — triggers on `seahawks_score` attribute change; condition checks the score delta is 6/7/8 (TD + PAT/2pt variants); pushes an 8-second `divoom_pixoo.show_message` with the animated touchdown GIF.
- `Pixoo - Seahawks Halftime` — triggers when `period` attribute transitions to `3` while game state is `in` (i.e. start of 3rd quarter, approximates halftime ending); pushes a 10-second halftime GIF.

**Note on HA quirks encountered:**
- This HA version uses the newer `triggers:`/`conditions:`/`actions:` (plural) schema and `trigger: state` / `action: xxx` syntax, not the older `trigger:`/`condition:`/`action:` singular + `platform:`/`service:` syntax.
- `from:` is only valid on a `state` trigger, not a `state` condition — caused an early "not a valid option" error.
- Automation editor's YAML mode expects a single automation object, not a list — pasting multiple automations at once must go through the File Editor directly into `automations.yaml`.

## Pixoo integration (`divoom_pixoo`, gickowtf/pixoo-homeassistant)

Confirmed working `show_message` service schema via Developer Tools > Actions:
```yaml
action: divoom_pixoo.show_message
target:
  entity_id: sensor.divoom_pixoo_64_current_page
data:
  page_data:
    page_type: components
    components:
      - type: image
        image_url: "<url>"
        position: [0, 0]
        resample_mode: box
  duration: 8
```
Valid `resample_mode` values: box (default), nearest/pixel_art, bilinear, hamming, bicubic, antialias/lanczos.

Score/kickoff rotation page (to be added via Settings > Devices & Services > Divoom Pixoo 64 > Configure, not automations.yaml):
```yaml
page_type: components
enabled: "{{ states('sensor.seahawks_game') in ['pre', 'in'] }}"
components:
  - type: image
    image_url: "http://10.0.25.X:3000/ian/pixoo-icons/raw/branch/main/football-score-background.jpg"
    position: [0, 0]
  - type: text
    content: >
      {% if states('sensor.seahawks_game') == 'in' %}
        SEA {{ state_attr('sensor.seahawks_game','seahawks_score') }}-{{ state_attr('sensor.seahawks_game','opponent_score') }} {{ state_attr('sensor.seahawks_game','opponent_abbr') }}
      {% else %}
        vs {{ state_attr('sensor.seahawks_game','opponent_abbr') }}
      {% endif %}
    position: [2, 5]
    font: pico_8
    color: white
  - type: text
    content: >
      {% if states('sensor.seahawks_game') == 'in' %}
        Q{{ state_attr('sensor.seahawks_game','period') }} {{ state_attr('sensor.seahawks_game','clock') }}
      {% else %}
        {{ as_timestamp(state_attr('sensor.seahawks_game','kickoff')) | timestamp_custom('%a %I:%M%p') }}
      {% endif %}
    position: [2, 20]
    font: pico_8
    color: white
```
**STATUS: not yet added to the device's page rotation** — still pending as of this writeup.

## Gitea assets (`gitea:ian/pixoo-icons`, flat repo root)
New files pushed:
- `seahawks-td-64.png` — static touchdown pixel-art image (downscaled from a 1200x1200 source via nearest-neighbor)
- `halftime-tecmo.gif` — 64x64, 8-frame halftime animation
- `seahawks-touchdown2.gif` — 64x64, 16-frame touchdown animation (the one actually wired into the automation)
- `football-score-background.jpg` — 64x64 background for the score/kickoff page
- (also uploaded but unused: `seahawk-touchdown.gif` padded to `seahawk-touchdown-64.gif`, `seahawks-touchdown3.jpg`, original unfixed `halftime.gif`/`halftime-64.gif`)

## Root cause found: MikroTik firewall gap
HA (10.0.20.X) could not reach Gitea (10.0.25.X:3000) to fetch page images — `ConnectTimeoutError` in HA logs. The original HA->Gitea icon-fetch exception rule (used for the existing weather/plant icons) was missing from the Controller's forward chain, apparently lost during the 2026-08-29 firewall cleanup that also touched the Lab->Infra DENY rule. Re-added:
```
chain=forward action=accept protocol=tcp src-address=10.0.20.X dst-address=10.0.25.X dst-port=3000 comment="HA -> Gitea icon fetch exception"
```
Placed before rule 29 (Lab -> Infra DENY). Confirmed fixed — `divoom_pixoo.show_message` now successfully renders both the static PNG and animated GIF pushes.

## Open items
- Score/kickoff rotation page not yet added to the Pixoo's page list via the integration's Configure UI.
- Pixoo showed up in an error log as `10.0.20.X`, not the documented static `10.0.20.X` — worth confirming which IP the integration is actually configured against before game day.
- Several unused touchdown/halftime image variants sitting in the pixoo-icons repo could be cleaned up later.
