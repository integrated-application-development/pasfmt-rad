# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

* Ignore formatting requests for files without matching file extensions (pas, dpr, dpk, inc).
* Fix error logging when cursor metadata is not parsed correctly.

### Changed

* Working directory for `pasfmt` is now set to the parent directory of the file being formatted.
  Previously, the parent directory of the active project file was used.

## [0.2.0] - 2025-03-18

### Added

* Support for updating breakpoints and bookmarks after the buffer rewrite.
* Confirmation prompt for formatting while debugging.

## [0.1.0] - 2025-02-20

### Added

* RAD Studio plugin adding in-editor formatting with [`pasfmt`](https://github.com/integrated-application-development/pasfmt).
* `Tools > Pasfmt > Format` action to format the active buffer.
* `Tools > Pasfmt > Settings...` to configure various user-level options.
* Format-on-save functionality.

[Unreleased]: https://github.com/integrated-application-development/delphilint/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/integrated-application-development/delphilint/compare/v0.1.0..v0.2.0
[0.1.0]: https://github.com/integrated-application-development/delphilint/releases/tag/v0.1.0