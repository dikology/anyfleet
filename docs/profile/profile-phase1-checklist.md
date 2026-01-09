# Phase 1 Implementation Checklist
**Profile Enhancement - Visual Foundation (Weeks 1-2)**

---

## Overview

Phase 1 adds core visual capabilities and essential profile fields:
- ✅ Profile image upload
- ✅ Bio/description
- ✅ Location & nationality
- ✅ Redesigned ProfileView with hero image
- ✅ Redesigned AuthorProfileModal with backdrop

---

## Backend Tasks

### 1. Database Migration
**File:** `alembic/versions/XXX_add_profile_fields_phase1.py`

- [ ] Create migration file
  ```bash
  cd anyfleet-backend
  alembic revision -m "add_profile_fields_phase1"
  ```

- [ ] Add columns to users table:
  ```python
  op.add_column('users', sa.Column('profile_image_url', sa.String(500), nullable=True))
  op.add_column('users', sa.Column('profile_image_thumbnail_url', sa.String(500), nullable=True))
  op.add_column('users', sa.Column('bio', sa.Text(), nullable=True))
  op.add_column('users', sa.Column('location', sa.String(100), nullable=True))
  op.add_column('users', sa.Column('nationality', sa.String(100), nullable=True))
  op.add_column('users', sa.Column('profile_visibility', sa.String(20), nullable=False, server_default='public'))
  ```

- [ ] Create indexes if needed
  ```python
  op.create_index('idx_users_profile_visibility', 'users', ['profile_visibility'])
  ```

- [ ] Write downgrade/rollback
- [ ] Test migration locally
- [ ] Apply migration to development database
  ```bash
  alembic upgrade head
  ```

### 2. Update Backend Models
**File:** `app/models/user.py`

- [ ] Add new fields to User model:
  ```python
  profile_image_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
  profile_image_thumbnail_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
  bio: Mapped[str | None] = mapped_column(Text, nullable=True)
  location: Mapped[str | None] = mapped_column(String(100), nullable=True)
  nationality: Mapped[str | None] = mapped_column(String(100), nullable=True)
  profile_visibility: Mapped[str] = mapped_column(String(20), nullable=False, default='public')
  ```

- [ ] Verify model loads correctly

### 3. Update Response Schemas
**File:** `app/schemas/auth.py`

- [ ] Update UserResponse:
  ```python
  class UserResponse(BaseModel):
      id: uuid.UUID
      email: EmailStr
      username: str | None = None
      role: str
      last_active_at: datetime | None = None
      created_at: datetime
      
      # Phase 1 additions
      profile_image_url: str | None = None
      profile_image_thumbnail_url: str | None = None
      bio: str | None = None
      location: str | None = None
      nationality: str | None = None
      profile_visibility: str = "public"
      
      model_config = {"from_attributes": True}
  ```

- [ ] Update UpdateProfileRequest:
  ```python
  class UpdateProfileRequest(BaseModel):
      username: str | None = Field(None, min_length=1, max_length=100)
      bio: str | None = Field(None, max_length=2000)
      location: str | None = Field(None, max_length=100)
      nationality: str | None = Field(None, max_length=100)
      profile_visibility: str | None = Field(None, pattern="^(public|private|community)$")
  ```

### 4. Image Upload Endpoint
**File:** `app/api/v1/profile.py` (new file)

- [ ] Create new router file
- [ ] Install Pillow for image processing
  ```bash
  poetry add Pillow
  # or
  pip install Pillow
  ```

- [ ] Implement upload endpoint:
  ```python
  from fastapi import APIRouter, UploadFile, Depends, HTTPException
  from PIL import Image
  import io
  
  router = APIRouter(prefix="/profile", tags=["profile"])
  
  @router.post("/upload-image")
  async def upload_profile_image(
      file: UploadFile,
      current_user: User = Depends(get_current_user)
  ):
      # Validate file type
      if not file.content_type.startswith('image/'):
          raise HTTPException(400, "File must be an image")
      
      # Read and validate image
      contents = await file.read()
      if len(contents) > 10 * 1024 * 1024:  # 10MB limit
          raise HTTPException(400, "Image too large (max 10MB)")
      
      try:
          image = Image.open(io.BytesIO(contents))
      except:
          raise HTTPException(400, "Invalid image file")
      
      # Compress and save full image
      # Generate thumbnail
      # Upload to storage
      # Update user record
      # Return URLs
  ```

- [ ] Implement image compression
- [ ] Implement thumbnail generation (400x400)
- [ ] Set up file storage (Railway volumes or S3)
- [ ] Test with various image formats
- [ ] Test with large files
- [ ] Add error handling

### 5. Update Profile Endpoint
**File:** `app/api/v1/auth.py`

- [ ] Update `update_profile` endpoint to accept new fields:
  ```python
  @router.patch("/profile", response_model=UserResponse)
  async def update_profile(
      profile_data: UpdateProfileRequest,
      current_user: User = Depends(get_current_user),
      db: Session = Depends(get_db)
  ):
      # Update username if provided
      if profile_data.username is not None:
          current_user.username = profile_data.username
      
      # Phase 1: Update new fields
      if profile_data.bio is not None:
          current_user.bio = profile_data.bio
      
      if profile_data.location is not None:
          current_user.location = profile_data.location
      
      if profile_data.nationality is not None:
          current_user.nationality = profile_data.nationality
      
      if profile_data.profile_visibility is not None:
          current_user.profile_visibility = profile_data.profile_visibility
      
      db.commit()
      db.refresh(current_user)
      return current_user
  ```

- [ ] Test with Postman/curl
- [ ] Verify validation works
- [ ] Test empty/null values

### 6. Register New Router
**File:** `app/main.py`

- [ ] Import profile router
  ```python
  from app.api.v1 import auth, profile
  ```

- [ ] Include in app
  ```python
  app.include_router(profile.router, prefix="/api/v1")
  ```

- [ ] Test endpoint is accessible

### 7. Create Seed Data
**File:** `app/scripts/seed_profiles.py` (new file)

- [ ] Create 10-20 sample users with:
  - Profile images (use placeholder services like unsplash.com)
  - Varied bios
  - Different locations/nationalities
  - Mix of completion levels

- [ ] Script to populate database
  ```bash
  python -m app.scripts.seed_profiles
  ```

### 8. API Documentation
- [ ] Update OpenAPI docs (FastAPI auto-generates)
- [ ] Test all endpoints in Swagger UI
- [ ] Document image upload requirements

---

## iOS Tasks

### 9. Update Models
**File:** `anyfleet/Services/AuthService.swift`

- [ ] Update UserInfo struct:
  ```swift
  struct UserInfo: Codable {
      let id: String
      let email: String
      let username: String?
      let createdAt: String
      
      // Phase 1 additions
      let profileImageUrl: String?
      let profileImageThumbnailUrl: String?
      let bio: String?
      let location: String?
      let nationality: String?
      let profileVisibility: String?
      
      enum CodingKeys: String, CodingKey {
          case id, email, username, bio, location, nationality
          case createdAt = "created_at"
          case profileImageUrl = "profile_image_url"
          case profileImageThumbnailUrl = "profile_image_thumbnail_url"
          case profileVisibility = "profile_visibility"
      }
  }
  ```

- [ ] Verify model decodes correctly
- [ ] Update preview data with new fields

### 10. Image Upload Service
**File:** `anyfleet/Services/ImageUploadService.swift` (new file)

- [ ] Create ImageUploadService class
  ```swift
  @MainActor
  @Observable
  final class ImageUploadService {
      var uploadProgress: Double = 0.0
      var isUploading = false
      var uploadError: AppError?
      
      func uploadProfileImage(_ image: UIImage) async throws -> (fullUrl: String, thumbnailUrl: String) {
          // Compress image
          // Upload to backend
          // Return URLs
      }
  }
  ```

- [ ] Implement image compression
  ```swift
  func compressImage(_ image: UIImage, targetSizeKB: Int = 2048) -> Data? {
      var compression: CGFloat = 1.0
      guard var imageData = image.jpegData(compressionQuality: compression) else {
          return nil
      }
      
      while imageData.count > targetSizeKB * 1024 && compression > 0.1 {
          compression -= 0.1
          guard let compressed = image.jpegData(compressionQuality: compression) else {
              break
          }
          imageData = compressed
      }
      
      return imageData
  }
  ```

- [ ] Implement upload with progress
- [ ] Add retry logic
- [ ] Add error handling
- [ ] Write unit tests

### 11. Image Picker Component
**File:** `anyfleet/Core/Components/ImagePicker.swift` (new file)

- [ ] Create ImagePicker using PHPickerViewController:
  ```swift
  struct ImagePicker: UIViewControllerRepresentable {
      @Binding var selectedImage: UIImage?
      @Environment(\.dismiss) var dismiss
      
      func makeUIViewController(context: Context) -> PHPickerViewController {
          var config = PHPickerConfiguration()
          config.filter = .images
          config.selectionLimit = 1
          
          let picker = PHPickerViewController(configuration: config)
          picker.delegate = context.coordinator
          return picker
      }
      
      // ... coordinator implementation
  }
  ```

- [ ] Handle image selection
- [ ] Handle cancellation
- [ ] Test on device (simulator has limited photos)

### 12. ProfileViewModel Enhancements
**File:** `anyfleet/Features/Profile/ProfileView.swift`

- [ ] Add new state properties:
  ```swift
  @Observable
  final class ProfileViewModel {
      // Existing...
      var appError: AppError?
      var isLoading = false
      
      // Phase 1 additions
      var isUploadingImage = false
      var uploadProgress: Double = 0.0
      var editedBio = ""
      var editedLocation = ""
      var editedNationality = ""
      var showImagePicker = false
      var selectedImage: UIImage?
  }
  ```

- [ ] Add image upload method:
  ```swift
  @MainActor
  func uploadProfileImage(_ image: UIImage, authService: AuthService) async {
      isUploadingImage = true
      defer { isUploadingImage = false }
      
      do {
          let imageService = ImageUploadService()
          let (fullUrl, thumbnailUrl) = try await imageService.uploadProfileImage(image)
          
          // Update user profile with new URLs
          await authService.loadCurrentUser()
      } catch {
          appError = error.toAppError()
      }
  }
  ```

- [ ] Add profile update method for new fields
- [ ] Update validation logic

### 13. ProfileHeroImage Component
**File:** `anyfleet/Features/Profile/Components/ProfileHeroImage.swift` (new file)

- [ ] Create hero image component:
  ```swift
  struct ProfileHeroImage: View {
      let imageUrl: String?
      let username: String
      let location: String?
      let isEditable: Bool
      let onEditTapped: () -> Void
      
      var body: some View {
          ZStack(alignment: .bottomLeading) {
              // Background image or gradient
              if let imageUrl = imageUrl, let url = URL(string: imageUrl) {
                  AsyncImage(url: url) { image in
                      image
                          .resizable()
                          .aspectRatio(contentMode: .fill)
                  } placeholder: {
                      gradientPlaceholder
                  }
              } else {
                  gradientPlaceholder
              }
              
              // Gradient overlay
              LinearGradient(
                  colors: [.clear, .black.opacity(0.7)],
                  startPoint: .top,
                  endPoint: .bottom
              )
              
              // User info
              VStack(alignment: .leading, spacing: 4) {
                  Text(username)
                      .font(.largeTitle)
                      .fontWeight(.bold)
                      .foregroundColor(.white)
                  
                  if let location = location {
                      Text(location)
                          .font(.body)
                          .foregroundColor(.white.opacity(0.9))
                  }
              }
              .padding()
              
              // Edit button (if editable)
              if isEditable {
                  Button(action: onEditTapped) {
                      Image(systemName: "camera.fill")
                          .foregroundColor(.white)
                          .padding(12)
                          .background(.ultraThinMaterial)
                          .clipShape(Circle())
                  }
                  .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                  .padding()
              }
          }
          .frame(height: 280)
          .clipShape(RoundedRectangle(cornerRadius: 16))
      }
      
      var gradientPlaceholder: some View {
          LinearGradient(
              colors: [Color(hex: "#4A90E2"), Color(hex: "#357ABD")],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
          )
      }
  }
  ```

- [ ] Add accessibility labels
- [ ] Test with various image sizes
- [ ] Test with no image

### 14. Bio Editor Component
**File:** `anyfleet/Features/Profile/Components/BioEditor.swift` (new file)

- [ ] Create bio editor:
  ```swift
  struct BioEditor: View {
      @Binding var bio: String
      let characterLimit: Int = 2000
      
      var body: some View {
          VStack(alignment: .trailing, spacing: 8) {
              TextEditor(text: $bio)
                  .frame(minHeight: 120)
                  .padding(8)
                  .background(Color.gray.opacity(0.1))
                  .cornerRadius(8)
                  .overlay(
                      RoundedRectangle(cornerRadius: 8)
                          .stroke(Color.blue, lineWidth: 1)
                  )
              
              Text("\(bio.count) / \(characterLimit)")
                  .font(.caption)
                  .foregroundColor(bio.count > characterLimit ? .red : .secondary)
          }
      }
  }
  ```

- [ ] Add character counter
- [ ] Add validation
- [ ] Handle long text gracefully

### 15. Update ProfileView
**File:** `anyfleet/Features/Profile/ProfileView.swift`

- [ ] Replace avatar section with ProfileHeroImage (lines ~218-238)
- [ ] Add image picker sheet:
  ```swift
  .sheet(isPresented: $viewModel.showImagePicker) {
      ImagePicker(selectedImage: $viewModel.selectedImage)
  }
  .onChange(of: viewModel.selectedImage) { oldValue, newValue in
      if let image = newValue {
          Task {
              await viewModel.uploadProfileImage(image, authService: authService)
          }
      }
  }
  ```

- [ ] Add bio section below hero
- [ ] Add location/nationality fields in editing mode
- [ ] Update save method to include new fields
- [ ] Add upload progress indicator

### 16. Update AuthorProfileModal
**File:** `anyfleet/Features/Discover/AuthorProfileModal.swift`

- [ ] Complete redesign with backdrop:
  ```swift
  struct AuthorProfileModal: View {
      let username: String
      let profileImageUrl: String?
      let bio: String?
      let location: String?
      let onDismiss: () -> Void
      
      var body: some View {
          ZStack {
              // Full-screen backdrop
              BackdropImage(url: profileImageUrl)
              
              // Content card
              VStack {
                  Spacer()
                  
                  ProfileInfoCard(
                      username: username,
                      bio: bio,
                      location: location,
                      onContact: handleContact
                  )
                  .padding()
              }
          }
          .toolbar {
              ToolbarItem(placement: .topBarTrailing) {
                  Button(action: onDismiss) {
                      Image(systemName: "xmark.circle.fill")
                          .foregroundColor(.white)
                          .shadow(radius: 4)
                  }
              }
          }
      }
  }
  ```

- [ ] Create BackdropImage component
- [ ] Create ProfileInfoCard component
- [ ] Add contact button (email composer)
- [ ] Test modal presentation
- [ ] Test with/without image

### 17. Localizations
**Files:** 
- `anyfleet/Resources/en.lproj/Localizable.strings`
- `anyfleet/Resources/ru.lproj/Localizable.strings`
- `anyfleet/Resources/Base.lproj/Localizable.strings`

- [ ] Add English strings:
  ```
  /* Profile Image */
  "profile.image.upload" = "Upload Profile Photo";
  "profile.image.change" = "Change Photo";
  "profile.image.remove" = "Remove Photo";
  "profile.image.uploading" = "Uploading...";
  "profile.image.error" = "Failed to upload image. Please try again.";
  
  /* Bio */
  "profile.bio.title" = "Bio";
  "profile.bio.placeholder" = "Tell others about yourself...";
  "profile.bio.characterLimit" = "%d / 2000 characters";
  
  /* Location */
  "profile.location.title" = "Location";
  "profile.location.placeholder" = "e.g., Ireland, Mediterranean";
  
  /* Nationality */
  "profile.nationality.title" = "Nationality";
  "profile.nationality.placeholder" = "e.g., Irish, American";
  
  /* Profile Completion */
  "profile.completion.title" = "Profile %d%% complete";
  "profile.completion.addPhoto" = "Add a profile photo";
  "profile.completion.addBio" = "Write your bio";
  ```

- [ ] Add Russian translations
- [ ] Add Base translations
- [ ] Run `swiftgen` to update L10n (if using)

### 18. Update Previews
**File:** `anyfleet/Features/Profile/ProfileView.swift`

- [ ] Update preview with Phase 1 fields:
  ```swift
  #Preview("Authenticated - Phase 1") {
      let authService = AuthService()
      authService.isAuthenticated = true
      authService.currentUser = UserInfo(
          id: "user-123",
          email: "john.doe@example.com",
          username: "Captain John",
          createdAt: "2024-01-15T10:30:00Z",
          profileImageUrl: "https://picsum.photos/1200/900",
          profileImageThumbnailUrl: "https://picsum.photos/400/400",
          bio: "Experienced sailor with 10+ years at sea. Love exploring new waters and teaching others the ropes.",
          location: "Mediterranean",
          nationality: "Italian",
          profileVisibility: "public"
      )
      
      return ProfileView()
          .environment(\.authService, authService)
  }
  ```

### 19. Image Caching
**File:** `anyfleet/Services/ImageCache.swift` (new file)

- [ ] Create simple image cache:
  ```swift
  actor ImageCache {
      static let shared = ImageCache()
      private var cache = NSCache<NSString, UIImage>()
      
      func get(_ url: String) -> UIImage? {
          cache.object(forKey: url as NSString)
      }
      
      func set(_ url: String, image: UIImage) {
          cache.setObject(image, forKey: url as NSString)
      }
  }
  ```

- [ ] Integrate with AsyncImage
- [ ] Set cache limits

---

## Testing Tasks

### 20. Backend Tests
**File:** `tests/test_profile.py` (new file)

- [ ] Test image upload endpoint:
  - Valid images (JPEG, PNG)
  - Invalid files
  - Too large files
  - Unauthorized access

- [ ] Test profile update:
  - Valid data
  - Bio over 2000 chars
  - Invalid visibility value
  - Unauthorized access

- [ ] Run tests:
  ```bash
  pytest tests/test_profile.py -v
  ```

### 21. iOS Unit Tests
**File:** `anyfleetTests/ProfileViewModelTests.swift`

- [ ] Test ProfileViewModel:
  - Bio validation
  - Image upload success
  - Image upload failure
  - Profile save with new fields

- [ ] Test ImageUploadService:
  - Image compression
  - Upload with progress
  - Error handling

- [ ] Run tests in Xcode (Cmd+U)

### 22. iOS UI Tests
**File:** `anyfleetUITests/ProfileUITests.swift`

- [ ] Test profile editing flow:
  - Tap edit button
  - Update bio, location, nationality
  - Save changes
  - Verify updates displayed

- [ ] Test image upload:
  - Tap camera button
  - Select image (mocked)
  - Verify upload progress
  - Verify image displays

- [ ] Run UI tests

### 23. Manual Testing

**Backend:**
- [ ] Upload various image formats (JPEG, PNG, HEIC)
- [ ] Upload oversized image (should fail)
- [ ] Upload 10+ images in sequence
- [ ] Update profile with new fields via API
- [ ] Verify URLs are correct
- [ ] Check image files in storage

**iOS:**
- [ ] Complete profile from scratch
  - Upload image
  - Write bio
  - Add location
  - Add nationality
  - Save
- [ ] Edit existing profile
- [ ] View another user's profile (AuthorProfileModal)
- [ ] Test on iPhone SE (smallest screen)
- [ ] Test on iPhone Pro Max (largest screen)
- [ ] Test with VoiceOver
- [ ] Test with largest Dynamic Type
- [ ] Test with slow network (Settings > Developer > Network Link Conditioner)
- [ ] Test offline (airplane mode)

---

## Integration Tasks

### 24. Environment Variables
**Backend `.env`:**
- [ ] Add storage configuration:
  ```
  STORAGE_TYPE=local  # or 's3'
  STORAGE_PATH=/uploads/profiles
  S3_BUCKET=anyfleet-profiles  # if using S3
  S3_REGION=us-east-1
  AWS_ACCESS_KEY_ID=...
  AWS_SECRET_ACCESS_KEY=...
  ```

**iOS:**
- [ ] Verify API base URL points to correct backend
- [ ] Test in simulator (local backend)
- [ ] Test on device (Railway backend)

### 25. Deploy Backend
- [ ] Commit changes to git
  ```bash
  git add .
  git commit -m "feat: Add Phase 1 profile fields and image upload"
  git push origin main
  ```

- [ ] Deploy to Railway (or your hosting)
- [ ] Run migrations on production:
  ```bash
  railway run alembic upgrade head
  ```

- [ ] Verify endpoints are accessible
- [ ] Check Swagger docs updated

### 26. Deploy iOS
- [ ] Update version/build number
- [ ] Test on TestFlight (internal)
- [ ] Submit to App Store review (when ready)

---

## Verification Checklist

### Backend Verification
- [ ] All migrations applied successfully
- [ ] `/api/v1/profile/upload-image` endpoint works
- [ ] `/api/v1/auth/profile` PATCH accepts new fields
- [ ] `/api/v1/auth/me` returns new fields
- [ ] Images stored correctly
- [ ] Thumbnails generated correctly
- [ ] API docs updated (Swagger)
- [ ] All tests passing

### iOS Verification
- [ ] UserInfo model decodes new fields
- [ ] Profile hero image displays correctly
- [ ] Image picker opens
- [ ] Image upload shows progress
- [ ] Bio editor works with char count
- [ ] Location/nationality editable
- [ ] AuthorProfileModal shows backdrop
- [ ] All new strings localized
- [ ] Previews work
- [ ] No linter errors
- [ ] All tests passing

### User Experience Verification
- [ ] Profile looks professional with image
- [ ] Placeholder gradient looks good without image
- [ ] Upload progress is clear
- [ ] Error messages are helpful
- [ ] Edit flow is intuitive
- [ ] Save confirmation is clear
- [ ] AuthorProfileModal is visually appealing
- [ ] Contact button is discoverable

---

## Common Issues & Solutions

### Issue: Image Upload Fails
**Symptoms:** 400/500 error when uploading  
**Solutions:**
- Check file size limit
- Verify content type validation
- Check storage permissions
- Verify backend has Pillow installed

### Issue: AsyncImage Not Loading
**Symptoms:** Images don't display in app  
**Solutions:**
- Check URL format (must be absolute URL)
- Verify backend serves images correctly
- Check iOS app info.plist for ATS settings
- Test URL in browser

### Issue: TextField/TextEditor Not Updating
**Symptoms:** Typing doesn't appear  
**Solutions:**
- Verify @State or @Binding is correct
- Check for conflicting modifiers
- Ensure ViewModel is @Observable

### Issue: Migration Fails
**Symptoms:** Alembic error when upgrading  
**Solutions:**
- Check for conflicting migrations
- Verify column types match database
- Drop and recreate dev database if needed
- Review migration SQL

---

## Next Steps After Phase 1

Once Phase 1 is complete and tested:
1. Review with stakeholders
2. Gather user feedback
3. Monitor metrics:
   - Profile completion rate
   - Image upload success rate
   - Profile view time
4. Address any issues
5. Begin Phase 2 planning (credentials & experience)

---

## Resources

**Backend:**
- FastAPI docs: https://fastapi.tiangolo.com
- Alembic docs: https://alembic.sqlalchemy.org
- Pillow docs: https://pillow.readthedocs.io

**iOS:**
- SwiftUI docs: https://developer.apple.com/documentation/swiftui
- PHPicker: https://developer.apple.com/documentation/photokit/phpickerviewcontroller
- AsyncImage: https://developer.apple.com/documentation/swiftui/asyncimage

**Design:**
- Reference images (provided)
- profile-design-mapping.md
- DesignSystem guidelines

---

**Estimated Time:**
- Backend: 16-20 hours
- iOS: 24-30 hours  
- Testing: 8-10 hours  
- **Total: 48-60 hours (1.5-2 weeks for 1 developer)**

Good luck! 🚀
