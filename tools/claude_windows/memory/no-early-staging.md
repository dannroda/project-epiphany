---
name: no-early-staging
description: "in the shared working tree never leave anything staged (no git rm / git add before the commit); other sessions' commits sweep the index"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 6d9b9e44-5f38-4fea-9355-1ae9026939fc
  modified: 2026-10-12T18:45:28.392Z
---

Parallel sessions share one working tree and one git index. Anything staged ahead of time ends up in whatever session commits next. On 2026-10-12, a `git rm src/ui/fader.*` staged for 14.9 went out inside -43's commit ede16c1, and HEAD briefly pointed to a deleted autoload.

**Why:** a commit takes the whole index, not just the files the committing session cares about.

**How to apply:**
- Delete with plain `rm`, then stage (`git add -A <paths>` or `git rm --cached`) in the same command as `git commit`.
- Before committing, check `git diff --cached --stat` for files from other sessions.

Related: [[session-split]], [[commit-per-task]].
