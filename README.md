# AnyFleet Sailing

AnyFleet is an offline-first iOS app for charter yacht management and crew education. It empowers sailors to organize their charter trips, create comprehensive checklists, and build a personal knowledge library of best practices.

## Features

### 🛥️ Charters
Create and manage sailing charters with comprehensive details:
- Charter planning with dates, locations, and vessel information
- Associate checklists for check-in, daily operations, and maintenance
- Active charter tracking with progress monitoring
- Charter-centric content organization

### 📚 Library
Build and organize your personal sailing knowledge base:
- **Checklists**: Structured checklists with sections and items for various yacht operations (pre-charter, check-in, daily, post-charter, emergency, maintenance, safety, provisioning)
- **Practice Guides**: Markdown-based guides for procedures and best practices
- **Flashcard Decks**: Study materials for crew education and certification prep
- Full CRUD operations with rich content creation tools
- Content tagging and categorization
- Private content by default with options for sharing

### 🔍 Discover
Explore community-created content:
- Browse publicly shared checklists, guides, and decks
- Fork content to customize for your needs
- Attribution tracking for original creators
- Community ratings and reviews

## Technology Stack

- **Platform**: iOS (SwiftUI)
- **Architecture**: MVVM with SwiftUI, offline-first design
- **Data Storage**: SQLite (via GRDB) for local persistence
- **State Management**: Observable objects with SwiftUI environment
- **Design System**: Custom component library with consistent theming
- **Networking**: Background sync service for content sharing
- **Testing**: Comprehensive unit and UI test suites

## Development

### Prerequisites
- Xcode 15.0+
- iOS 17.0+
- Swift 5.9+

### Setup
1. Clone the repository
2. Open `anyfleet.xcodeproj` in Xcode
3. Build and run on simulator or device

### Project Structure
```
anyfleet/
├── Core/           # Domain models, stores, utilities
├── Features/       # Feature-specific views and view models
├── DesignSystem/   # Reusable UI components and theming
├── Data/          # Database and data access layers
├── Services/      # External service integrations
└── Resources/     # Localization and assets
```

## Philosophy

**"Your personal sailing companion."** AnyFleet is built on core principles:

- **Offline-First**: All core functionality works without internet connectivity
- **Personal Ownership**: Users create and manage their own content library
- **Charter-Centric**: Content is organized around charter trips with execution tracking
- **Community-Powered**: Future phases will enable content sharing and collaboration

Currently in **Phase 1: Personal Utility Foundation**, focusing on individual productivity and offline capabilities. Phase 2 will introduce community features and content sharing.

## CI/CD

This project uses Fastlane and GitHub Actions for continuous integration and deployment.

- **Tests**: Run automatically on all pull requests
- **TestFlight**: Deployments happen on merge to main when commit message includes `[deploy]`

See [fastlane/README.md](fastlane/README.md) for detailed setup instructions.

## App Store Connect Credentials

To deploy to TestFlight, you need App Store Connect API credentials. Here's how to set them up:

### 1. Create an App Store Connect API Key

1. Go to [App Store Connect](https://appstoreconnect.apple.com/)
2. Navigate to **Users and Access** → **Keys** → **App Store Connect API**
3. Click the **+** button to create a new key
4. Give it a name (e.g., "Fastlane CI")
5. Select the **App Manager** role (or **Admin** if you need full access)
6. Click **Generate**
7. **Important**: Download the `.p8` key file immediately (you can only download it once!)
8. Note the **Key ID** and **Issuer ID** (shown on the page)

You'll need three values:
- **Key ID**: The 10-character identifier (e.g., `ABC123DEFG`)
- **Issuer ID**: The UUID (e.g., `12345678-1234-1234-1234-123456789012`)
- **Private Key**: The contents of the `.p8` file you downloaded

### 2. Local Development Setup

For local builds and TestFlight uploads, set up the API key:

```bash
# Create the directory for API keys
mkdir -p ~/.appstoreconnect/private_keys

# Copy your .p8 file to the directory with the correct naming format
# The filename must be: AuthKey_<KEY_ID>.p8
cp /path/to/your/key.p8 ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8
```

Then set environment variables when running fastlane:

```bash
export APP_STORE_CONNECT_API_KEY_ID="<YOUR_KEY_ID>"
export APP_STORE_CONNECT_ISSUER_ID="<YOUR_ISSUER_ID>"
bundle exec fastlane ios beta
```

### 3. GitHub Actions Setup

For CI/CD, add these secrets to your GitHub repository:

1. Go to your repository → **Settings** → **Secrets and variables** → **Actions**
2. Add the following secrets:

| Secret Name | Value | Description |
|------------|-------|-------------|
| `APP_STORE_CONNECT_API_KEY_ID` | Your Key ID | The 10-character key identifier |
| `APP_STORE_CONNECT_ISSUER_ID` | Your Issuer ID | The UUID issuer identifier |
| `APP_STORE_CONNECT_API_KEY_CONTENT` | Contents of `.p8` file | The entire contents of the private key file |
| `FASTLANE_USER` | Your Apple ID email | Apple ID used for App Store Connect |
| `FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD` | App-specific password | See below for how to create this |

### 4. Create an App-Specific Password

For two-factor authentication, you need an app-specific password:

1. Go to [appleid.apple.com](https://appleid.apple.com/)
2. Sign in and go to **Sign-In and Security** → **App-Specific Passwords**
3. Click **Generate an app-specific password**
4. Give it a label (e.g., "Fastlane CI")
5. Copy the generated password (it won't be shown again)
6. Add it as the `FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD` secret

### 5. Verify Setup

Test your credentials locally:

```bash
# Set environment variables
export APP_STORE_CONNECT_API_KEY_ID="<YOUR_KEY_ID>"
export APP_STORE_CONNECT_ISSUER_ID="<YOUR_ISSUER_ID>"
export FASTLANE_USER="<YOUR_APPLE_ID>"
export FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD="<YOUR_APP_SPECIFIC_PASSWORD>"

# Test the build (local development export)
bundle exec fastlane ios build_local

# Test TestFlight upload (requires all credentials)
bundle exec fastlane ios beta
```

### Troubleshooting

- **"No profiles found"**: Use `bundle exec fastlane ios build_local` for local builds
- **"Invalid API key"**: Verify the Key ID, Issuer ID, and that the `.p8` file is correctly named and placed
- **"Authentication failed"**: Check that the API key has the correct permissions and hasn't been revoked
- **"Two-factor authentication required"**: Make sure you're using an app-specific password, not your regular Apple ID password

For more details, see the [Fastlane documentation on App Store Connect API](https://docs.fastlane.tools/app-store-connect-api/).
