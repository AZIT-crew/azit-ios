import Foundation

enum AppConfig {

    static let webURL: URL = {
        guard let value = Bundle.main.infoDictionary?["WEB_URL"] as? String,
              let url = URL(string: value), url.host != nil else {
            fatalError("Info.plist의 WEB_URL이 없거나 올바른 URL이 아니에요.")
        }
        return url
    }()

    static let apiURL: URL = {
        guard let value = Bundle.main.infoDictionary?["API_URL"] as? String,
              let url = URL(string: value), url.host != nil else {
            fatalError("Info.plist의 API_URL이 없거나 올바른 URL이 아니에요.")
        }
        return url
    }()

    static let kakaoAppKey: String = {
        guard let value = Bundle.main.infoDictionary?["KAKAO_APP_KEY"] as? String, !value.isEmpty else {
            fatalError("Info.plist의 KAKAO_APP_KEY가 없어요.")
        }
        return value
    }()

    static let kakaoRedirectURI: String = "azit://oauth/kakao"
}
