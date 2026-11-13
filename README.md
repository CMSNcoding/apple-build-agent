# apple-build-agent

GitHub Actions pipelines that let an LLM agent compile and package Apple platform
projects (iOS / macOS) without a local Mac.

## What it does

- Generates the `.xcodeproj` from `project.yml` via [XcodeGen] (keeps the repo
  free of binary Xcode project files that are painful for LLM agents to edit)
- Builds an **unsigned `.ipa`** for device install
- Also builds the simulator variant to catch API-level breakage
- Uploads the artifact so it can be downloaded and sideloaded

## Layout

```
.github/workflows/ios.yml   CI pipeline
project.yml                 XcodeGen project spec
Sources/App/App.swift       app sources
```

## Notes

- Unsigned `.ipa` must be signed before installing on a device —
  use Sideloadly / AltStore with a free Apple ID (valid 7 days).
- Public repos get unlimited macOS runner minutes; private repos are billed
  at 10x (2000 min/month quota → ~200 macOS minutes).
- Bump `deploymentTarget.iOS` in `project.yml` to match the target device.

[XcodeGen]: https://github.com/yonaskolb/XcodeGen
