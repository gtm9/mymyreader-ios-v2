# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Automated UI tests for Home and Profile tabs.
- Automated unit tests setup.
- Initial Qwen3-TTS local inference via MLX-Swift.

### Fixed
- Fixed Azure DevOps CI pipeline failures caused by missing UI test targets and Accessibility Identifiers.
- Bypassed MLX Metal initialization during automated tests to prevent SIGABRT on CI runners.

## [1.0.0] - 2026-05-30
### Added
- Initial project generation using XcodeGen.
- Basic Audio Recording and Playback mechanisms.
