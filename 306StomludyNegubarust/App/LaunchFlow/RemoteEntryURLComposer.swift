//
//  RemoteEntryURLComposer.swift
//

import Foundation

struct RemoteEntryURLComposer {

    let template: String
    let trackingParameterName: String

    init(
        template: String = LaunchFlowSecrets.remoteFlowEntryTemplate,
        trackingParameterName: String = LaunchFlowSecrets.trackingSegmentParameterName
    ) {
        self.template = template
        self.trackingParameterName = trackingParameterName
    }

    func composedURL() -> URL? {
        let geo = Locale.current.region?.identifier ?? "XX"
        let appHandle = marketingHandle.replacingOccurrences(of: " ", with: "")
        let subValue = "\(appHandle)_\(geo)"
        guard var components = URLComponents(string: template) else { return nil }
        var items = components.queryItems ?? []
        items.append(URLQueryItem(name: trackingParameterName, value: subValue))
        components.queryItems = items
        return components.url
    }

    private var marketingHandle: String {
        if let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String,
           !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "App"
    }
}
