# Journal -- 2026-08-30: Zabbix

Assigned Zabbix as part of the CascadeSteam internship. Used my homelab as
a sandbox to actually get hands-on before/alongside doing the real
internship deployment -- theory alone wasn't going to stick.

## What I learned about the core pieces

- Items -- this is the actual unit of data collection. Every metric you
  want (CPU load, disk usage, a service being up) is an item tied to a
  host, with its own polling interval. Understanding this made the rest
  of Zabbix click -- everything else (triggers, dashboards, alerts) is
  built on top of items.

- Macros -- instead of writing a separate trigger for every host, macros
  let one template apply everywhere with host-specific values swapped in.
  This is what makes Zabbix scale past a handful of machines -- you're
  not hand-writing config per box.

- Templates -- pre-built bundles of items/triggers for a specific thing
  (Proxmox, MikroTik, Docker, PostgreSQL). Learned that picking the right
  template type matters: HTTP-based templates (API token auth) for
  Proxmox, SNMP for the MikroTik, agent-based for Docker/Postgres.
  Different monitoring targets fundamentally need different transport
  methods, not just different item sets.

- UserParameters -- when there's no template for what you need, you write
  your own check as a UserParameter (I did this for LVM thin-pool usage,
  which isn't covered out of the box). This taught me Zabbix isn't just
  "install and pick from a menu" -- sometimes you're writing the actual
  monitoring logic yourself.

- Agent vs Agent2 -- Agent2 is the modern default; better plugin support.
  Learned to prefer it for new deployments.

- Server setup -- did this twice with two different DB backends (Postgres
  on my homelab instance, MariaDB on the CascadeSteam one), which was
  actually useful -- I saw that the core Zabbix concepts don't change
  based on DB choice, but the setup friction (encoding, service startup,
  permissions) is backend-specific.

## Real mistakes that taught me something

- Ran an install on the Proxmox host instead of inside the LXC container
  by mistake -- caught it because the host's OS version didn't match what
  the Zabbix repo expected. Lesson: always confirm which shell prompt
  you're actually in before running anything, especially in a nested
  Proxmox-host/LXC-guest setup.

- Spent time debugging a "connection reset" between the Zabbix server and
  an agent -- turned out the agent config still pointed at 127.0.0.1 for
  the server address instead of the real IP. Lesson: config files that
  ship with active (not commented-out) default values need to be found
  and edited by exact content, not assumed to be placeholder comments you
  can safely pattern-match.

## Bigger-picture takeaway

Zabbix isn't one monitoring approach -- it's a framework that adapts its
method (SNMP, HTTP/API, agent, custom script) to whatever it's
monitoring. A router, a database, and a thin-pool volume all need
genuinely different plumbing even inside the same tool. That variety is
what took the most time to get comfortable with.
