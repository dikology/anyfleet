# anyfleet
a comprehensive toolset for sailing captains

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
