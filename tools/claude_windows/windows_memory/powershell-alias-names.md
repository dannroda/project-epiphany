---
name: powershell-alias-names
description: In Windows PowerShell 5.1 built-in aliases (measure, select, where, sort…) beat script functions of the same name; never name .ps1 functions like that
metadata:
  type: feedback
---

In `measure_shaders.ps1` a function called `measure` never ran, because `measure` is the alias of `Measure-Object` and aliases win over functions in PowerShell 5.1. It was renamed to `MeasureBuild`.

**Why:** the failure is silent; the alias just runs with odd output.

**How to apply:** name functions in `.ps1` scripts Verb-Noun or with a project prefix; check `Get-Alias <name>` first. Also, in 5.1 `$PSScriptRoot` is empty inside `param()` defaults.

Related: [[windows-session]].
