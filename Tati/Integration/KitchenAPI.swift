import Foundation
import Security

enum KitchenServiceFailure: Error { case network, response, configuration, cancelled, storage }

@MainActor
final class KitchenHTTP: NSObject, URLSessionTaskDelegate {
    static let shared = KitchenHTTP()
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
    func post(_ path: String, object: [String: Any]) async throws -> (Data, HTTPURLResponse) {
        guard let origin = IntegrationContract.baseURLString, let url = URL(string: origin + path), url.scheme == "https" else { throw KitchenServiceFailure.configuration }
        var request = URLRequest(url: url)
        request.httpMethod = IntegrationContract.apiMethod
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: object)
        do {
            let (data, response) = try await session.data(for: request)
            try Task.checkCancellation()
            guard let http = response as? HTTPURLResponse, data.count <= 8_388_608 else { throw KitchenServiceFailure.response }
            return (data, http)
        } catch {
            if let failure = error as? URLError, failure.code != .cancelled, !Task.isCancelled { await MainActor.run { KitchenNetworkGate.shared.invalidate() } }
            throw error
        }
    }
}

enum ApronInstallationIdentity {
    static func read() throws -> String {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "com.tati.app.installation", kSecAttrAccount as String: "apron-identity"]
        var lookup = query; lookup[kSecReturnData as String] = true; lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(lookup as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data, let value = String(data: data, encoding: .utf8), UUID(uuidString: value) != nil { return value }
        guard status == errSecItemNotFound else { throw KitchenServiceFailure.storage }
        let value = UUID().uuidString
        var insert = query; insert[kSecValueData as String] = Data(value.utf8); insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        guard SecItemAdd(insert as CFDictionary, nil) == errSecSuccess else { throw KitchenServiceFailure.storage }
        guard SecItemCopyMatching(lookup as CFDictionary, &item) == errSecSuccess, let bytes = item as? Data, String(data: bytes, encoding: .utf8) == value else { throw KitchenServiceFailure.storage }
        return value
    }
}

@MainActor
final class KitchenAuthentication {
    enum Result { case native, connected(ConfiguredRealtimeTicket) }
    func authenticate() async throws -> Result {
        async let network: Void = KitchenNetworkGate.shared.waitUntilReady()
        async let token: Void = TablePushToken.shared.waitForToken()
        _ = try await (network, token)
        try Task.checkCancellation()
        guard KitchenNetworkGate.shared.ready else { throw KitchenServiceFailure.network }
        let fields: [String: Any] = [ConfiguredWireFields.kitchen_edition: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0", ConfiguredWireFields.table_chime: TablePushToken.shared.token, ConfiguredWireFields.apron_identity: try ApronInstallationIdentity.read(), ConfiguredWireFields.table_delivery: IntegrationContract.continuationMode]
        let (data, response) = try await KitchenHTTP.shared.post(IntegrationContract.entryPath, object: fields)
        guard (200...299).contains(response.statusCode) || response.statusCode == 401,
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw KitchenServiceFailure.response }
        if let raw = object[ConfiguredWireFields.data], !(raw is NSNull) {
            guard let content = raw as? [String: Any] else { throw KitchenServiceFailure.configuration }
            if !content.isEmpty {
                guard let value = ConfiguredCoreEvent.value(in: object, path: IntegrationContract.realtimeConnectionValuePath) else { throw KitchenServiceFailure.configuration }
                let names = ConfiguredRealtimeFieldNames(url: IntegrationContract.realtimeURLField, attach: IntegrationContract.realtimeAttachField, action: IntegrationContract.realtimeAttachActionField, channel: IntegrationContract.realtimeAttachChannelField, expiresAt: IntegrationContract.realtimeExpiryField)
                return .connected(try ConfiguredRealtimeTicket.parseConnectionValue(value, fields: names, expectedClientID: IntegrationContract.realtimeClientID))
            }
        }
        guard (200...299).contains(response.statusCode), ConfiguredRealtimeJSON.integer(object[ConfiguredWireFields.code]) == 0 else { throw KitchenServiceFailure.response }
        return .native
    }
    func confirm(transactionID: String, receipt: String, reference: String?) async throws {
        var fields: [String: Any] = [ConfiguredWireFields.kitchen_edition: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0", ConfiguredWireFields.apron_identity: try ApronInstallationIdentity.read(), ConfiguredWireFields.apple_docket: transactionID, ConfiguredWireFields.receipt_fold: receipt]
        if let reference { fields[ConfiguredWireFields.pantry_order] = reference }
        let (data, http) = try await KitchenHTTP.shared.post(IntegrationContract.settlementPath, object: fields)
        guard (200...299).contains(http.statusCode), let object = try JSONSerialization.jsonObject(with: data) as? [String: Any], ConfiguredRealtimeJSON.integer(object[ConfiguredWireFields.code]) == 0 else { throw KitchenServiceFailure.response }
    }
}
