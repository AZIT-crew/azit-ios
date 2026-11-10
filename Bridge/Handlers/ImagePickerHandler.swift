import AVFoundation
import Foundation
import PhotosUI
import UIKit

final class ImagePickerHandler: NSObject {

    private weak var bridge: AppBridge?
    private weak var viewController: UIViewController?
    private var pendingMethod: String?
    private var pendingEventId: String?

    init(bridge: AppBridge, viewController: UIViewController?) {
        self.bridge = bridge
        self.viewController = viewController
    }

    func pickProfileImage(source: String, method: String, eventId: String) {
        pendingMethod = method
        pendingEventId = eventId
        DispatchQueue.main.async { [weak self] in
            if source == "camera" {
                self?.openCamera()
            } else {
                self?.openLibrary()
            }
        }
    }

    private func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            finish(result: ["success": false, "message": "카메라를 사용할 수 없습니다."]); return
        }
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                guard granted else {
                    self?.finish(result: ["success": false, "message": "카메라 권한이 필요합니다."]); return
                }
                let picker = UIImagePickerController()
                picker.sourceType = .camera
                picker.allowsEditing = true
                picker.delegate = self
                self?.viewController?.present(picker, animated: true)
            }
        }
    }

    private func openLibrary() {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        viewController?.present(picker, animated: true)
    }

    private func finish(result: [String: Any]) {
        guard let method = pendingMethod, let eventId = pendingEventId else { return }
        pendingMethod = nil
        pendingEventId = nil
        bridge?.respondObject(method: method, eventId: eventId, value: result)
    }

    private func processImage(_ image: UIImage) {
        let size = CGSize(width: 512, height: 512)
        let resized = UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let data = resized.jpegData(compressionQuality: 0.7) else {
            finish(result: ["success": false, "message": "이미지 압축에 실패했습니다."]); return
        }
        finish(result: [
            "success": true,
            "base64": data.base64EncodedString(),
            "fileName": "profile_\(Int(Date().timeIntervalSince1970)).jpg",
            "mimeType": "image/jpeg"
        ])
    }
}

extension ImagePickerHandler: PHPickerViewControllerDelegate {

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let item = results.first else {
            finish(result: ["success": false, "message": "이미지 선택이 취소되었습니다."]); return
        }
        item.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let image = object as? UIImage else {
                self?.finish(result: ["success": false, "message": "이미지를 불러올 수 없습니다."]); return
            }
            self?.processImage(image)
        }
    }
}

extension ImagePickerHandler: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        picker.dismiss(animated: true)
        let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage
        guard let image else {
            finish(result: ["success": false, "message": "이미지 데이터를 읽을 수 없습니다."]); return
        }
        processImage(image)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        finish(result: ["success": false, "message": "이미지 선택이 취소되었습니다."])
    }
}
