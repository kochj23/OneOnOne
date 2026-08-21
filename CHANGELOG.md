# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Multi-model LLM load balancer layered onto the existing AIService providers:
  OpenRouter frontier models (one Keychain-stored key), an optional Nova Gateway
  backend, and balanced dispatch across all discovered local models (Ollama + MLX).
- Three settings toggles (use all local models / enable all frontier models /
  route through Nova Gateway). Meeting-summary generation and other AI features
  route through balanced dispatch when a toggle is on, and fall back to the
  single-provider path otherwise. Ollama and the other providers keep working.
- Network-free `LoadBalancerTests` covering discovery parsing, pool composition,
  and the round-robin / least-busy selection policies.

### Fixed
- Pre-existing launch crash (not introduced by this change): `CloudKitService`
  eagerly called `CKContainer(identifier:)` at startup, which os_crashes an
  unsigned XCTest / CI host app (no iCloud entitlement) before any test runs.
  CloudKit setup is now skipped under XCTest, disabling sync gracefully. This
  lets `xcodebuild test` (and CI) run; production launches are unaffected.

### Changed
- CI (`build.yml`) upgraded from build-only to `xcodebuild test` on macOS with a
  Metal Toolchain step, mirroring the AIStudio workflow.

### Planned
- Performance improvements
- Additional features based on community feedback

## [1.0.0] - 2025-01-01

### Added
- Initial release
- Core functionality
- macOS native interface
- MIT License

---

*For detailed release notes, see [GitHub Releases](https://github.com/kochj23/OneOnOne/releases).*
