fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios test

```sh
[bundle exec] fastlane ios test
```

Run tests

### ios build

```sh
[bundle exec] fastlane ios build
```

Build and archive the app

### ios build_local

```sh
[bundle exec] fastlane ios build_local
```

Build and archive the app (local development - uses development export)

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Upload to TestFlight

### ios ci

```sh
[bundle exec] fastlane ios ci
```

Run tests and upload to TestFlight if on main branch

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
