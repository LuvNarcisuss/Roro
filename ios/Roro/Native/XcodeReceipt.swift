#if DEBUG && targetEnvironment(simulator)
import CryptoKit
import Foundation
import Security
import SwiftASN1

/// Reads the single-signer PKCS #7 format emitted by StoreKit Testing in Xcode.
enum XcodeReceipt {
    private enum ReceiptError: Error { case invalid }
    private static let explicit = ASN1Identifier(tagWithNumber: 0, tagClass: .contextSpecific)
    // SHA-256 of Xcode's IDEStoreKitEditor/Contents/Resources/StoreKitTestCertificate.cer.
    private static let certificateHash = "ff0ba36e721d2db741d2aa11e6112ef78bf7131b46c7f035b00891d045c864fe"

    /// Returns nil for other issuers so Apple receipts keep their regular verification path.
    static func verify(_ data: Data) throws -> [String: Any]? {
        let info = try fields(BER.parse(Array(data)), .sequence, count: 2)
        guard try ASN1ObjectIdentifier(berEncoded: info[0]) == "1.2.840.113549.1.7.2" else { return nil }
        let wrapper = try fields(info[1], explicit, count: 1)
        let signed = try fields(wrapper[0], .sequence)
        guard signed.count == 5, let certificates = try? fields(signed[3], explicit, count: 1) else { return nil }
        let der = Data(certificates[0].encodedBytes)
        guard SHA256.hash(data: der).map({ String(format: "%02x", $0) }).joined() == certificateHash else { return nil }

        let encapsulated = try fields(signed[2], .sequence, count: 2)
        guard try ASN1ObjectIdentifier(berEncoded: encapsulated[0]) == "1.2.840.113549.1.7.1" else { throw ReceiptError.invalid }
        let content = try fields(encapsulated[1], explicit, count: 1)
        let payload = try ASN1OctetString(berEncoded: content[0]).bytes
        let signers = try fields(signed[4], .set, count: 1)
        let signer = try fields(signers[0], .sequence, count: 5)
        let signature = try ASN1OctetString(derEncoded: signer[4]).bytes
        guard let certificate = SecCertificateCreateWithData(nil, der as CFData),
              let key = SecCertificateCopyKey(certificate),
              SecKeyVerifySignature(key, .rsaSignatureMessagePKCS1v15SHA256, Data(payload) as CFData,
                                    Data(signature) as CFData, nil) else { throw ReceiptError.invalid }

        let receipt = try attributes(DER.parse(payload))
        guard try string(receipt[0]) == "Xcode",
              try string(receipt[2]) == Bundle.main.bundleIdentifier else { throw ReceiptError.invalid }
        let purchases: [[String: Any]] = try (receipt[17] ?? []).compactMap { node in
            let purchase = try attributes(node)
            guard purchase[1712] == nil else { return nil }
            guard let quantity = purchase[1701], quantity.count == 1 else { throw ReceiptError.invalid }
            return ["transaction_id": try string(purchase[1703]), "product_id": try string(purchase[1702]),
                    "quantity": String(try Int(derEncoded: quantity[0]))]
        }
        return ["environment": "Xcode", "receipt": ["bundle_id": try string(receipt[2]), "in_app": purchases]]
    }

    private static func fields(_ node: ASN1Node, _ identifier: ASN1Identifier, count: Int? = nil) throws -> [ASN1Node] {
        guard node.identifier == identifier, case let .constructed(nodes) = node.content else { throw ReceiptError.invalid }
        let children = Array(nodes)
        guard count == nil || children.count == count else { throw ReceiptError.invalid }
        return children
    }

    private static func attributes(_ node: ASN1Node) throws -> [Int: [ASN1Node]] {
        var result: [Int: [ASN1Node]] = [:]
        for field in try fields(node, .set) {
            let values = try fields(field, .sequence, count: 3)
            let id = try Int(derEncoded: values[0])
            // Other fields include opaque data that is not ASN.1 encoded.
            if [0, 2, 17, 1701, 1702, 1703, 1712].contains(id) {
                let bytes = try ASN1OctetString(derEncoded: values[2]).bytes
                result[id, default: []].append(try DER.parse(bytes))
            }
        }
        return result
    }

    private static func string(_ values: [ASN1Node]?) throws -> String {
        guard let values, values.count == 1 else { throw ReceiptError.invalid }
        return try String(ASN1UTF8String(derEncoded: values[0]))
    }
}
#endif
