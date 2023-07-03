# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/) and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.0] - 2023-07-03

### Added

- `require "t"` now requires a file that only requires `"sorbet/eraser/t"`, so they are effectively the same thing. If you're in a situation where you need to load a different `"t"`, then you can manually require `"sorbet/eraser/t"` and it should work.
- Replace all `typed:` comments with `typed: ignore`.

## [0.3.1] - 2023-06-27

### Added

- Shims for `T::Configuration`, `T::Private::RuntimeLevels`, and `T::Methods`.

### Changed

- Fixed various parsing bugs due to incorrect location.

## [0.3.0] - 2023-06-27

### Added

- Support for the `default` and `without_accessors` options for `T::Struct`.

## [0.2.0] - 2023-06-26

### Added

- Better support for `T::Struct` subclasses.

## [0.1.1] - 2021-11-17

### Changed

- Require MFA for releasing.

[unreleased]: https://github.com/kddnewton/sorbet-eraser/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/kddnewton/sorbet-eraser/compare/v0.3.1...v0.4.0
[0.3.1]: https://github.com/kddnewton/sorbet-eraser/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/kddnewton/sorbet-eraser/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/kddnewton/sorbet-eraser/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/kddnewton/sorbet-eraser/compare/f6a712...v0.1.1
