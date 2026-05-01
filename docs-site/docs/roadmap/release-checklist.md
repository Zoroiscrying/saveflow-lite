---
sidebar_position: 2
title: 0.9 RC Release Checklist
---

0.9.x is the SaveFlow Lite release-candidate line.

Use this checklist before publishing any 0.9.x build.

## Release Scope

Allowed:

- bug fixes
- test coverage
- packaging validation
- install and upgrade validation
- documentation consistency fixes
- wording fixes for diagnostics, setup health, and reference pages

Avoid:

- new broad public APIs
- Pro orchestration features
- migration registry or save upgrade pipeline
- cloud sync
- background save pipeline
- reference repair systems

## Install And Upgrade Matrix

Validate these paths:

| Path | Expected result |
| --- | --- |
| Fresh addons zip install | `addons/saveflow_core` and `addons/saveflow_lite` copy cleanly into an empty project. |
| Fresh Godot Asset Library style install | Archive root contains only `addons/`. |
| Demo zip open | Demo project opens with `addons/`, `demo/saveflow_lite`, `project.godot`, and README. |
| Existing 0.8.7 project overwrite | Replacing the addon folders keeps the `SaveFlow` autoload and project settings usable. |
| Docs-site/repository clone | Repository-only paths stay outside install guidance and release addon zips. |

## Local Verification

Run:

```powershell
.\tools\import_project.ps1
.\tools\run_gdunit.ps1 -ContinueOnFailure
.\tools\release\validate_saveflow_lite_upgrade.ps1
.\tools\release\validate_saveflow_lite_mono_clean_install.ps1 -ZipPath <addons-zip>
```

Build the docs site:

```powershell
cd docs-site
npm run build
```

## Release Asset Verification

`publish_saveflow_lite.ps1` must verify:

- `plugin.cfg`, `addons/saveflow_core/version.txt`, README, and changelog version consistency
- addons-only zip allowed roots
- demo zip allowed roots
- forbidden repository roots are absent from release zips
- Asset Library archive exports only `addons/`
- SHA-256 checksum manifest exists for the zip assets
- clean install validation passes for the generated addons-only zip
- 0.8.7-to-current upgrade validation passes for the generated addons-only zip
- Mono clean install validation passes for the generated addons-only zip
- published release validation passes after GitHub release upload

The clean install validation expands the addons zip into a temporary Godot
project, enables SaveFlow Lite, confirms the `SaveFlow` autoload persists, runs
a runtime smoke script, and runs Godot `--check-only`.

The upgrade validation expands the 0.8.7 addons zip into a temporary Godot
project, enables SaveFlow Lite, overwrites the addon folders with the current
addons zip, confirms the `SaveFlow` autoload and project settings persist, runs
a runtime smoke script, and runs Godot `--check-only`.

The checksum manifest is uploaded as
`saveflow-lite-v{version}-SHA256SUMS.txt` and includes one SHA-256 entry for the
addons zip and one for the addons-demo zip.

The Mono clean install validation expands the addons zip into a temporary Godot
C# project, enables SaveFlow Lite, builds a minimal `SaveFlowClient` smoke
project, runs the smoke scene, and runs Godot `--check-only`.

The published release validation downloads the GitHub Release assets for the
tag, verifies the checksum manifest against the downloaded zip files, checks the
release zip shape again, and reruns clean install plus Mono clean install against
the downloaded addons zip.

After release upload, the same published release validation can be rerun with:

```powershell
.\tools\release\validate_saveflow_lite_published_release.ps1 -Version <version>
```

## Release Notes

For 0.9.x, release notes should emphasize:

- RC hardening
- fixed regressions
- install/package validation
- docs/API consistency

Do not present 0.9.x as a new feature line.
