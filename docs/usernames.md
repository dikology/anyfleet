## Current Issue

The iOS app correctly requests the `.fullName` scope, but it only extracts the `identityToken` from the `ASAuthorizationAppleIDCredential`. The `fullName` property contains the user's actual name but is being ignored.

## What Apple's ASAuthorizationAppleIDCredential Provides

```swift
let credential = authorization.credential as? ASAuthorizationAppleIDCredential
// Currently extracted:
credential.identityToken  // JWT token with user ID, email
// NOT extracted:
credential.fullName       // PersonNameComponents with first/last name
credential.email          // Email address
```

## Required Changes

### 1. Update iOS AuthService to Extract Full Name

```swift:82:104:anyfleet/anyfleet/anyfleet/Services/AuthService.swift
func handleAppleSignIn(result: Result<ASAuthorization, Error>) async throws {
    AppLogger.auth.startOperation("Apple Sign In")
    
    switch result {
    case .success(let authorization):
        AppLogger.auth.debug("Received Apple authorization")
        
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = appleIDCredential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            AppLogger.auth.error("Failed to extract identity token from Apple credential")
            throw AuthError.invalidToken
        }
        
        // Extract user info including full name
        var userInfo: [String: Any] = [:]
        
        // Add full name if available
        if let fullName = appleIDCredential.fullName {
            var nameComponents: [String: String] = [:]
            if let givenName = fullName.givenName {
                nameComponents["firstName"] = givenName
            }
            if let familyName = fullName.familyName {
                nameComponents["lastName"] = familyName
            }
            if !nameComponents.isEmpty {
                userInfo["name"] = nameComponents
            }
        }
        
        // Add email if available (backup)
        if let email = appleIDCredential.email {
            userInfo["email"] = email
        }
        
        AppLogger.auth.debug("Identity token and user info extracted, sending to backend")
        try await signInWithBackend(identityToken: tokenString, userInfo: userInfo.isEmpty ? nil : userInfo)
        AppLogger.auth.completeOperation("Apple Sign In")
        
    case .failure(let error):
        AppLogger.auth.failOperation("Apple Sign In", error: error)
        throw error
    }
}
```

### 2. Update Backend Apple Auth Service to Extract Name

```python:229:244:anyfleet-backend/app/services/apple_auth.py
def extract_email_from_token(self, token_payload: dict) -> str:
    """Extract email from Apple token payload."""
    return token_payload.get("email", "")

def extract_apple_id_from_token(self, token_payload: dict) -> str:
    """Extract Apple user ID (sub) from token payload."""
    return token_payload.get("sub", "")

def extract_display_name_from_token(self, token_payload: dict) -> str | None:
    """Extract display name from Apple token payload."""
    name_data = token_payload.get("name")
    if name_data and isinstance(name_data, dict):
        first_name = name_data.get("firstName", "")
        last_name = name_data.get("lastName", "")
        if first_name or last_name:
            return f"{first_name} {last_name}".strip()
    return None

def is_email_verified(self, token_payload: dict) -> bool:
    """Check if email is verified in the token."""
    # Apple's email_verified can be a string "true" or boolean True
    email_verified = token_payload.get("email_verified", False)
    if isinstance(email_verified, str):
        return email_verified.lower() == "true"
    return bool(email_verified)
```

### 3. Update Backend Auth Endpoint to Use Display Name

```python:55:120:anyfleet-backend/app/api/v1/auth.py
@router.post(
    "/apple-signin",
    response_model=TokenResponse,
    status_code=status.HTTP_200_OK,
)
@limiter.limit("5/15minutes")
async def apple_signin(
    request: Request,
    signin_data: AppleSignInRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    settings: Annotated[Settings, Depends(get_settings)],
    jwt_service: Annotated[JWTService, Depends(get_jwt_service)],
) -> TokenResponse:
    """
    Sign in or sign up with Apple.

    This endpoint:
    1. Validates the identity token with Apple
    2. Creates a new user if they don't exist
    3. Returns access and refresh tokens
    """
    logger.info("Apple sign-in request received")
    apple_service = AppleAuthService(settings)

    # Verify the identity token
    logger.debug("Verifying Apple identity token")
    token_payload = await apple_service.verify_identity_token(
        signin_data.identity_token
    )

    if token_payload is None:
        logger.warning("Invalid Apple identity token provided")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid identity token",
        )

    # Extract user information
    apple_id = apple_service.extract_apple_id_from_token(token_payload)
    email = apple_service.extract_email_from_token(token_payload)
    
    # Try to get display name from multiple sources
    display_name = None
    
    # 1. From user_info sent by iOS app (preferred)
    if signin_data.user_info and "name" in signin_data.user_info:
        name_data = signin_data.user_info["name"]
        if isinstance(name_data, dict):
            first_name = name_data.get("firstName", "")
            last_name = name_data.get("lastName", "")
            if first_name or last_name:
                display_name = f"{first_name} {last_name}".strip()
    
    # 2. From identity token (fallback, but rare)
    if display_name is None:
        display_name = apple_service.extract_display_name_from_token(token_payload)
    
    logger.debug(f"Extracted Apple ID: {apple_id[:8]}..., Email: {email}, Name: {display_name}")

    # Apple ID is always required
    if not apple_id:
        logger.warning("Missing Apple user ID from token")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Missing Apple user ID",
        )

    # Check if user exists
    result = await db.execute(select(User).where(User.apple_id == apple_id))
    user = result.scalar_one_or_none()

    if user is None:
        # New user - email is required from token
        if not email:
            logger.warning(
                f"Missing email for new user with Apple ID: {apple_id[:8]}..."
            )
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email required for new user registration",
            )

        # Verify email if present
        if not apple_service.is_email_verified(token_payload):
            logger.warning(f"Email not verified for Apple ID: {apple_id[:8]}...")
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email not verified",
            )

        # Create new user with display name as username
        logger.info(
            f"Creating new user for Apple ID: {apple_id[:8]}..., Email: {email}, Name: {display_name}"
        )
        user = User(
            apple_id=apple_id,
            email=email,
            username=display_name,  # Set username from Apple display name
        )
        db.add(user)
        await db.flush()  # Flush to get the user ID
        await db.refresh(user)
        logger.info(f"New user created with ID: {user.id}")
    else:
        # Existing user - update username if not set and we have a display name
        logger.info(f"Existing user found: {user.id}, Email: {user.email}")
        if user.username is None and display_name is not None:
            logger.info(f"Updating username for existing user: {display_name}")
            user.username = display_name

    # Create tokens...
```

## Important Apple Sign In Behavior

**Critical limitation**: Apple's name sharing only works on the **first sign-in**. Once a user has signed in and shared their name, subsequent sign-ins won't include the name again - it will be `nil`.

This means:
- New users will get their display name set on first sign-in
- Existing users who signed in before this change won't get names unless they delete and re-add the app
- The backend should preserve the username once it's set
