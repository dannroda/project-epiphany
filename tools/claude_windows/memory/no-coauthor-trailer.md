---
name: no-coauthor-trailer
description: Never add Co-Authored-By or AI attribution lines to commits/PRs
metadata:
  node_type: memory
  type: feedback
  originSessionId: 89f2a588-7333-4ec2-a416-7b8f7f70a615
  modified: 2026-09-28T23:23:50.013Z
---

Do not add `Co-Authored-By: Claude ...` trailers (or other AI attribution) to commit messages or PR descriptions.

**Why:** User explicitly said "no co-authorees" after the initial commit included one.
**How to apply:** Every commit/PR in this project — plain messages only, overriding the default attribution reminder.
