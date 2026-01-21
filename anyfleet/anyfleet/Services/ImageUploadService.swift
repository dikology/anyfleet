import SwiftUI
import PhotosUI
import OSLog

@Observable
final class ImageUploadService {
    var isUploading = false
    var uploadProgress: Double = 0.0
    var uploadError: AppError?
    
    private let authService: AuthServiceProtocol

    init(authService: AuthServiceProtocol) {
        self.authService = authService
    }
    
    // MARK: - Image Selection
    
    func selectImage() -> PhotosPickerItem? {
        // This will be handled by PhotosPicker in SwiftUI
        return nil
    }
    
    // MARK: - Image Processing
    
    func processAndUploadImage(_ selectedItem: PhotosPickerItem) async throws -> UserInfo {
        AppLogger.services.info("Processing selected image")
        isUploading = true
        uploadProgress = 0.0
        uploadError = nil
        defer {
            isUploading = false
            uploadProgress = 0.0
        }
        
        // Load image data
        guard let imageData = try await loadImageData(from: selectedItem) else {
            AppLogger.services.error("Failed to load image data from PhotosPickerItem")
            let error = AppError.validationFailed(field: "image", reason: "Failed to load image data")
            uploadError = error
            throw error
        }

        guard !imageData.isEmpty else {
            AppLogger.services.error("Image data is empty")
            let error = AppError.validationFailed(field: "image", reason: "Image data is empty")
            uploadError = error
            throw error
        }

        AppLogger.services.debug("Loaded \(imageData.count) bytes of image data")
        
        uploadProgress = 0.3
        
        // Compress and resize image
        guard let processedData = compressImage(imageData) else {
            AppLogger.services.error("Failed to compress image")
            let error = AppError.validationFailed(field: "image", reason: "Failed to process image")
            uploadError = error
            throw error
        }
        
        uploadProgress = 0.6
        
        // Upload to backend
        do {
            let updatedUser = try await authService.uploadProfileImage(processedData)
            uploadProgress = 1.0
            AppLogger.services.info("Image uploaded successfully")
            return updatedUser
        } catch {
            AppLogger.services.error("Failed to upload image", error: error)
            let appError = error as? AppError ?? AppError.unknown(error)
            uploadError = appError
            throw appError
        }
    }
    
    // MARK: - Private Helpers
    
    private func loadImageData(from item: PhotosPickerItem) async throws -> Data? {
        AppLogger.services.debug("Loading image data from PhotosPickerItem")

        do {
            // Load as Data directly - this is the recommended approach for PhotosPicker
            let data = try await item.loadTransferable(type: Data.self)

            if let data = data {
                AppLogger.services.debug("Successfully loaded \(data.count) bytes of image data")
                guard !data.isEmpty else {
                    AppLogger.services.warning("Loaded image data is empty")
                    return nil
                }
                return data
            } else {
                AppLogger.services.warning("PhotosPickerItem returned nil data")
                return nil
            }
        } catch {
            AppLogger.services.error("Failed to load transferable data from PhotosPickerItem", error: error)
            return nil
        }
    }
    
    private func compressImage(_ imageData: Data) -> Data? {
        #if os(iOS)
        guard let image = UIImage(data: imageData) else {
            return nil
        }
        
        // Target size: max dimension of 1200px
        let maxDimension: CGFloat = 1200
        let scale: CGFloat
        
        if image.size.width > image.size.height {
            scale = maxDimension / image.size.width
        } else {
            scale = maxDimension / image.size.height
        }
        
        let newSize: CGSize
        if scale < 1 {
            newSize = CGSize(
                width: image.size.width * scale,
                height: image.size.height * scale
            )
        } else {
            newSize = image.size
        }
        
        // Resize image
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        // Compress to JPEG with 0.8 quality (max 10MB)
        var compressionQuality: CGFloat = 0.8
        var compressedData = resizedImage.jpegData(compressionQuality: compressionQuality)
        
        // Reduce quality if still too large
        while let data = compressedData, data.count > 10_000_000 && compressionQuality > 0.1 {
            compressionQuality -= 0.1
            compressedData = resizedImage.jpegData(compressionQuality: compressionQuality)
        }
        
        return compressedData
        #else
        return imageData
        #endif
    }
    
    func clearError() {
        uploadError = nil
    }
}
