import CryptoKit
import Flutter
import Speech
import UIKit

/// The iPhone side of the channels Android has in OfflineChannels.kt and MainActivity.kt.
/// Nothing here leaves the phone.
/// - "magana/offline": an upright copy of a photo for on-device text recognition (ML Kit),
///   crops of it so each number is read a second time, and a flattened copy for faint print. Files live in the app's private caches
///   folder and the app deletes each one as soon as it is read.
/// - "magana/vault": AES-GCM with a 256-bit key kept in the Keychain (this device only), for
///   photos waiting for a full reading (lib/offline/photo_queue.dart). Same format as Android:
///   the 12-byte nonce, then the ciphertext and the 16-byte tag.
/// - "magana/speech": whether this iPhone recognises English speech on the device. When the app
///   asks for on-device recognition, speech_to_text sets requiresOnDeviceRecognition, so iOS
///   never sends that audio to Apple; under-18s have no other Apple step (voice_input.dart).
/// - "magana/device": the model identifier ("iPhone14,2") for problem reports.
enum MaganaChannels {
  static let maxSide: CGFloat = 2400
  static let keyService = "ng.magana.app.queue"
  static let keyAccount = "magana_queue"

  static func register(_ messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: "magana/offline", binaryMessenger: messenger).setMethodCallHandler { call, result in
      let a = call.arguments as? [String: Any] ?? [:]
      do {
        switch call.method {
        case "upright":
          guard let bytes = a["bytes"] as? FlutterStandardTypedData else { throw ChannelError.badArguments }
          result(try upright(bytes.data))
        case "crop":
          guard let path = a["path"] as? String, let left = a["left"] as? Int, let top = a["top"] as? Int,
                let width = a["width"] as? Int, let height = a["height"] as? Int, let scale = a["scale"] as? Double
          else { throw ChannelError.badArguments }
          result(try crop(path: path, left: left, top: top, width: width, height: height, scale: scale))
        case "flatten":
          guard let path = a["path"] as? String else { throw ChannelError.badArguments }
          result(try flatten(path: path))
        case "delete":
          guard let path = a["path"] as? String else { throw ChannelError.badArguments }
          result((try? FileManager.default.removeItem(atPath: path)) != nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      } catch {
        result(FlutterError(code: "offline", message: String(describing: type(of: error)), details: nil))
      }
    }
    FlutterMethodChannel(name: "magana/vault", binaryMessenger: messenger).setMethodCallHandler { call, result in
      let a = call.arguments as? [String: Any] ?? [:]
      do {
        guard let bytes = (a["bytes"] as? FlutterStandardTypedData)?.data else { throw ChannelError.badArguments }
        switch call.method {
        case "encrypt":
          guard let sealed = try AES.GCM.seal(bytes, using: try key()).combined else { throw ChannelError.crypto }
          result(FlutterStandardTypedData(bytes: sealed))
        case "decrypt":
          let box = try AES.GCM.SealedBox(combined: bytes)
          result(FlutterStandardTypedData(bytes: try AES.GCM.open(box, using: try key())))
        default:
          result(FlutterMethodNotImplemented)
        }
      } catch {
        result(FlutterError(code: "vault", message: String(describing: type(of: error)), details: nil))
      }
    }
    FlutterMethodChannel(name: "magana/speech", binaryMessenger: messenger).setMethodCallHandler { call, result in
      switch call.method {
      case "onDeviceAvailable":
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        result(recognizer?.supportsOnDeviceRecognition ?? false)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    FlutterMethodChannel(name: "magana/device", binaryMessenger: messenger).setMethodCallHandler { call, result in
      switch call.method {
      case "model":
        var info = utsname()
        uname(&info)
        let machine = withUnsafeBytes(of: &info.machine) { raw in
          String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
        result("Apple \(machine)")
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  enum ChannelError: Error { case badArguments, notAnImage, crypto, keychain }

  static func cacheFile(_ ext: String) throws -> URL {
    let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("offline")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("offline_\(UUID().uuidString).\(ext)")
  }

  /// The photo turned upright (its EXIF orientation), at most maxSide wide or tall, as a private JPEG.
  static func upright(_ data: Data) throws -> [String: Any] {
    guard let image = UIImage(data: data) else { throw ChannelError.notAnImage }
    let s = min(1, maxSide / max(image.size.width, image.size.height))
    let size = CGSize(width: (image.size.width * s).rounded(), height: (image.size.height * s).rounded())
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let drawn = UIGraphicsImageRenderer(size: size, format: format).image { _ in
      image.draw(in: CGRect(origin: .zero, size: size))  // draw() applies the orientation
    }
    guard let jpeg = drawn.jpegData(compressionQuality: 0.92) else { throw ChannelError.notAnImage }
    let out = try cacheFile("jpg")
    try jpeg.write(to: out, options: .completeFileProtection)
    return ["path": out.path, "width": Int(size.width), "height": Int(size.height)]
  }

  /// A crop of an upright photo, scaled by [scale], on a white border (like the server's).
  static func crop(path: String, left: Int, top: Int, width: Int, height: Int, scale: Double) throws -> String {
    guard let source = UIImage(contentsOfFile: path)?.cgImage else { throw ChannelError.notAnImage }
    let x = min(max(left, 0), source.width - 1)
    let y = min(max(top, 0), source.height - 1)
    let w = max(1, min(width, source.width - x))
    let h = max(1, min(height, source.height - y))
    guard let cut = source.cropping(to: CGRect(x: x, y: y, width: w, height: h)) else { throw ChannelError.notAnImage }
    let sw = max(1, CGFloat(Double(w) * scale).rounded(.down))
    let sh = max(1, CGFloat(Double(h) * scale).rounded(.down))
    let border: CGFloat = 32
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let framed = UIGraphicsImageRenderer(size: CGSize(width: sw + 2 * border, height: sh + 2 * border), format: format)
      .image { ctx in
        UIColor.white.setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: sw + 2 * border, height: sh + 2 * border))
        UIImage(cgImage: cut).draw(in: CGRect(x: border, y: border, width: sw, height: sh))
      }
    guard let png = framed.pngData() else { throw ChannelError.notAnImage }
    let out = try cacheFile("png")
    try png.write(to: out, options: .completeFileProtection)
    return out.path
  }

  /// Thermal or faint print (as the server's reader.flatten_contrast and OfflineChannels.kt):
  /// each pixel divided by the blurred paper around it, then stretched to full contrast (1%
  /// clipped at each end). The blur is three small box blurs on an image an eighth of the size,
  /// sampled back bilinearly. Returns a grey private JPEG, like upright().
  static func flatten(path: String) throws -> [String: Any] {
    guard let cg = UIImage(contentsOfFile: path)?.cgImage else { throw ChannelError.notAnImage }
    let w = cg.width, h = cg.height
    var bytes = [UInt8](repeating: 0, count: w * h)
    guard let ctx = CGContext(data: &bytes, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                              space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
    else { throw ChannelError.notAnImage }
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
    let s = 8, sw = (w + s - 1) / s, sh = (h + s - 1) / s
    var small = [Float](repeating: 0, count: sw * sh)
    var count = [Float](repeating: 0, count: sw * sh)
    for y in 0..<h {
      for x in 0..<w {
        let i = (y / s) * sw + x / s
        small[i] += Float(bytes[y * w + x])
        count[i] += 1
      }
    }
    for i in 0..<small.count { small[i] /= count[i] }
    for _ in 0..<3 { small = boxBlur(small, sw, sh, 3) }
    var v = [Float](repeating: 0, count: w * h)
    var hist = [Int](repeating: 0, count: 256)
    for y in 0..<h {
      let fy = min(max((Float(y) + 0.5) / Float(s) - 0.5, 0), Float(sh - 1))
      let y0 = Int(fy), y1 = min(y0 + 1, sh - 1), ty = fy - Float(y0)
      for x in 0..<w {
        let fx = min(max((Float(x) + 0.5) / Float(s) - 0.5, 0), Float(sw - 1))
        let x0 = Int(fx), x1 = min(x0 + 1, sw - 1), tx = fx - Float(x0)
        let bg = small[y0 * sw + x0] * (1 - ty) * (1 - tx) + small[y0 * sw + x1] * (1 - ty) * tx
          + small[y1 * sw + x0] * ty * (1 - tx) + small[y1 * sw + x1] * ty * tx
        let f = min(max(Float(bytes[y * w + x]) / (bg + 1) * 235, 0), 255)
        v[y * w + x] = f
        hist[min(255, Int(f))] += 1
      }
    }
    let clip = (w * h) / 100
    var lo = 0, hi = 255, acc = 0
    for i in 0...255 { acc += hist[i]; if acc >= clip { lo = i; break } }
    acc = 0
    for i in stride(from: 255, through: 0, by: -1) { acc += hist[i]; if acc >= clip { hi = i; break } }
    let span = Float(max(1, hi - lo))
    for i in 0..<(w * h) { bytes[i] = UInt8(min(max((v[i] - Float(lo)) * 255 / span, 0), 255)) }
    guard let outCtx = CGContext(data: &bytes, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                 space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue),
          let flat = outCtx.makeImage(), let jpeg = UIImage(cgImage: flat).jpegData(compressionQuality: 0.92)
    else { throw ChannelError.notAnImage }
    let out = try cacheFile("jpg")
    try jpeg.write(to: out, options: .completeFileProtection)
    return ["path": out.path, "width": w, "height": h]
  }

  /// A box blur of radius r, across then down (edges repeat).
  static func boxBlur(_ a: [Float], _ w: Int, _ h: Int, _ r: Int) -> [Float] {
    let k = Float(2 * r + 1)
    var across = [Float](repeating: 0, count: a.count)
    for y in 0..<h {
      for x in 0..<w {
        var sum: Float = 0
        for d in -r...r { sum += a[y * w + min(max(x + d, 0), w - 1)] }
        across[y * w + x] = sum / k
      }
    }
    var down = [Float](repeating: 0, count: a.count)
    for y in 0..<h {
      for x in 0..<w {
        var sum: Float = 0
        for d in -r...r { sum += across[min(max(y + d, 0), h - 1) * w + x] }
        down[y * w + x] = sum / k
      }
    }
    return down
  }

  /// The queue's key: made once, kept in the Keychain for this device only (never backed up).
  static func key() throws -> SymmetricKey {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keyService,
      kSecAttrAccount as String: keyAccount, kSecReturnData as String: true,
    ]
    var found: CFTypeRef?
    if SecItemCopyMatching(query as CFDictionary, &found) == errSecSuccess, let data = found as? Data {
      return SymmetricKey(data: data)
    }
    let made = SymmetricKey(size: .bits256)
    let add: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keyService,
      kSecAttrAccount as String: keyAccount,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
      kSecValueData as String: made.withUnsafeBytes { Data($0) },
    ]
    guard SecItemAdd(add as CFDictionary, nil) == errSecSuccess else { throw ChannelError.keychain }
    return made
  }
}
