fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Code Signing Setup (Match)

This project uses [fastlane match](https://docs.fastlane.tools/actions/match/) for code signing management.

## Initial Setup (One-time, local)

1. **Create a private Git repository** for storing certificates and provisioning profiles
   - Create a new private GitHub/GitLab/Bitbucket repository (e.g., `certificates`)

2. **Initialize match**:
   ```sh
   cd anyfleet
   bundle exec fastlane match init
   ```
   - Choose option 4 (git storage)
   - Enter your certificates repository URL
   - Choose option 1 (appstore) for App Store distribution

3. **Generate certificates and profiles**:
   ```sh
   bundle exec fastlane match appstore
   ```
   This will:
   - Create certificates and provisioning profiles
   - Store them in your git repository
   - Install them locally

## CI/CD Setup

Add these secrets to your GitHub repository (Settings → Secrets and variables → Actions):

- `MATCH_GIT_URL` - URL of your certificates repository (e.g., `https://github.com/username/certificates.git`)
- `MATCH_GIT_BRANCH` - Branch name (default: `main`)
- `MATCH_PASSWORD` - Password to encrypt certificates in the repository
- `MATCH_KEYCHAIN_PASSWORD` - Password for the temporary CI keychain
- `APP_STORE_CONNECT_API_KEY_ID` - Your App Store Connect API Key ID
- `APP_STORE_CONNECT_ISSUER_ID` - Your App Store Connect Issuer ID
- `APP_STORE_CONNECT_API_KEY_CONTENT` - Content of your `.p8` key file

## Local Development

For local development builds, use:
```sh
bundle exec fastlane ios build_local
```

This uses development provisioning profiles.

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
