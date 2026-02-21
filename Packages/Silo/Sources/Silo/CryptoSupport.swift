import Foundation

#if canImport(CommonCrypto)
import CommonCrypto
#endif

#if canImport(CryptoKit)
import CryptoKit
#elseif canImport(CryptoSwift)
import CryptoSwift
#endif

enum CryptoSupport {
    static func decryptAESCBC(payload: Data, key: Data, iv: Data) -> Data? {
        #if canImport(CommonCrypto)
        var outLength: size_t = 0
        var outData = Data(count: payload.count + kCCBlockSizeAES128)
        let outCapacity = outData.count
        let status = outData.withUnsafeMutableBytes { outBytes in
            payload.withUnsafeBytes { payloadBytes in
                iv.withUnsafeBytes { ivBytes in
                    key.withUnsafeBytes { keyBytes in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress,
                            key.count,
                            ivBytes.baseAddress,
                            payloadBytes.baseAddress,
                            payload.count,
                            outBytes.baseAddress,
                            outCapacity,
                            &outLength)
                    }
                }
            }
        }
        guard status == kCCSuccess else { return nil }
        outData.removeSubrange(outLength..<outData.count)
        return outData
        #elseif canImport(CryptoSwift)
        do {
            let aes = try AES(
                key: Array(key),
                blockMode: CBC(iv: Array(iv)),
                padding: .pkcs7)
            let decrypted = try aes.decrypt(Array(payload))
            return Data(decrypted)
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    static func decryptAESGCM(payload: Data, key: Data) -> Data? {
        guard payload.count >= 12 + 16 else { return nil }
        let nonce = payload.prefix(12)
        let cipherTag = payload.dropFirst(12)
        let ciphertext = cipherTag.dropLast(16)
        let tag = cipherTag.suffix(16)
        #if canImport(CryptoKit)
        do {
            let nonce = try AES.GCM.Nonce(data: nonce)
            let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
            return try AES.GCM.open(sealedBox, using: SymmetricKey(data: key))
        } catch {
            return nil
        }
        #elseif canImport(CryptoSwift)
        do {
            let gcm = GCM(iv: Array(nonce), mode: .combined)
            let aes = try AES(key: Array(key), blockMode: gcm, padding: .noPadding)
            let combined = Array(ciphertext) + Array(tag)
            let decrypted = try aes.decrypt(combined)
            return Data(decrypted)
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }
}
