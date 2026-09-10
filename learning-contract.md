# Learning Contract — Cascade STEAM Technology Internship

**Course:** CIS190 6001, Summer 2026
**Credits:** 5 (165 hours, ~24 hrs/week)
**Status:** draft — pending supervisor and instructor review

Bracketed numbers are placeholders. Confirm with supervisor before submitting;
these become the grading criteria at end of term.

---

## Job Description

As a Technology Intern at Cascade STEAM Service Corps, a nonprofit MSP, I
assist in technology management and development while participating in
technology-driven community service programs across four community groups:
Artificial Intelligence, Cyber, Spectrum, and Open Source.

Specific duties include designing and deploying automated backup systems;
performing system recovery and restore drills; provisioning and maintaining
containerized services on Proxmox using LXC, VM, and Docker workloads;
terminating and testing network cabling and troubleshooting physical and
network-layer faults; providing public technology support on scheduled Help
Desk and Digital Navigators dates; and producing documentation and system
artifacts in PDF and DOCX format.

---

## Outcome 1 — Backup

*CIS program outcome 2 · Skills Acquisition*

**Learning Outcome:** Within 30 days I will be able to design and deploy an
automated, encrypted backup system that runs unattended on a daily schedule
and works from outside the home network, with at least [20] successful
scheduled snapshots logged.

**Learning Activities:** I will select the tool and transport against the
actual constraints rather than defaults, deploy the repository and
scheduling, and test the off-network path over cellular rather than assuming
the LAN result carries.

**Evaluation:** Snapshot history showing [20] consecutive daily runs including
at least [3] from off-network, plus my supervisor reviewing the repository
configuration.

---

## Outcome 2 — Recovery

*CIS program outcome 2 · Skills Acquisition*

**Learning Outcome:** Within 30 days I will be able to rebuild a failed system
from backup into a fresh virtual machine — OS, installed applications, home
directory, and configuration — and state a measured recovery time, completing
at least [2] full restore drills.

**Learning Activities:** I will capture an application manifest alongside the
data, provision a clean VM, restore into it, and record every gap between what
came back and what a working system needs.

**Evaluation:** A written restore drill report per attempt with elapsed time
and gaps found, with the second drill faster and cleaner than the first,
reviewed by my supervisor.

---

## Outcome 3 — Containers and virtualization

*CIS program outcome 1 · Skills Acquisition*

**Learning Outcome:** Within 30 days I will be able to provision and hand off
services on Proxmox — LXC containers, VMs, and Docker workloads — including
storage and backup configuration, standing up at least [3] services someone
else can restart or rebuild from my documentation.

**Learning Activities:** I will build each service in a test container before
production, configure its backup at deployment rather than after, and hand it
off with a runbook someone else executes while I watch.

**Evaluation:** Each service in production with a second person successfully
performing a restart or rebuild from my runbook without asking me questions.

---

## Outcome 4 — Networking and hardware troubleshooting

*CIS program outcomes 3, 5 · Skills Acquisition*

**Learning Outcome:** Within 30 days I will be able to terminate and test
Cat5e/Cat6 to spec and troubleshoot faults across the physical and network
layers — cabling, VLAN routing, firewall rules, and overlay mesh connectivity
— terminating at least [15] ends that pass a tester and resolving at least [6]
network faults.

**Learning Activities:** I will practice terminations on scrap until they pass
consistently before running live drops, test every run, and work each network
fault by layer instead of guessing, logging what I ruled out at each step.

**Evaluation:** Tester pass rate on my first five terminations against my last
five, plus a fault log showing the elimination steps, reviewed by my
supervisor.

---

## Outcome 5 — Documentation

*Supports CIS program outcomes 1, 2, 3 · Skills Acquisition*

**Learning Outcome:** Within 30 days I will produce a written playbook covering
the backup, recovery, and deployment work above, in PDF or DOCX, that a
co-worker can follow end to end without asking me questions.

**Learning Activities:** I will write each section as I complete the work it
covers, keep it version-controlled, and have my supervisor mark what isn't
clear.

**Evaluation:** My supervisor signs off on the finished playbook, and one
section is validated by someone else executing it successfully.

---

## Before Submitting

- [ ] Fill in all bracketed numbers with realistic targets
- [ ] Confirm scope with supervisor — the plan doc attached to the Symplicity
      form lists Help Desk, ERP, and open source migration; these outcomes
      describe backup, recovery, containers, and networking. Get the mismatch
      resolved in writing.
- [ ] Send to instructor (Saunders / Rose) for review — required by the
      reviewer's note, and faculty approval is already overdue
- [ ] Replace the job description field on the form with the version above
- [ ] Resubmit in Symplicity

## Reviewer History

| Date | Reviewer | Outcome |
|------|----------|---------|
| 2026-07-05 | — | Submitted |
| 2026-07-06 | Staff | Revision: hours short of 165; need one outcome per credit |
| 2026-07-14 | — | Resubmitted with corrected hours |
| 2026-07-15 | Staff | Revision: hours accepted; still need 5 separate outcomes |
