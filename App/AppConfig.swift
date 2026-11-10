import Foundation

enum AppConfig {

    static let webURL: URL = {
        guard let value = Bundle.main.infoDictionary?["WEB_URL"] as? String,
              let url = URL(string: value), url.host != nil else {
            fatalError("Info.plist의 WEB_URL이 없거나 올바른 URL이 아니에요. xcconfig 연결을 확인하세요.")
        }
        return url
    }()
}
