// Apple Vision on a Mac, with exactly the iPhone app's VisionText (copied in by run.sh from
// app/ios/Runner/MaganaChannels.swift), to compare with ML Kit. Counts only for private photos:
//   tools/vision/run.sh <image> [--text]   (--text only for synthetic test images)
import CoreGraphics
import Foundation
import ImageIO

let args = CommandLine.arguments
guard args.count >= 2, let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: args[1]) as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
  print("cannot open"); exit(1)
}
let lines = try VisionText.lines(image)
let words = lines.flatMap { $0["words"] as! [[String: Any]] }
let confs = words.map { $0["confidence"] as! Double }
let numbers = words.filter { ($0["text"] as! String).rangeOfCharacter(from: .decimalDigits) != nil }
let sureNumbers = numbers.filter { ($0["confidence"] as! Double) >= 0.9 }
let mean = confs.isEmpty ? 0 : confs.reduce(0, +) / Double(confs.count)
print("lines \(lines.count) words \(words.count) with confidence \(confs.count) mean \(String(format: "%.2f", mean)) numbers \(numbers.count) numbers >= 0.90 \(sureNumbers.count)")
if args.contains("--boxes") {
  // Word boxes and confidences only (no text), for the show-through check (vision_show_through.py).
  let boxes = lines.map { ($0["words"] as! [[String: Any]]).map { [$0["left"]!, $0["top"]!, $0["width"]!, $0["height"]!, $0["confidence"]!] } }
  print(String(data: try JSONSerialization.data(withJSONObject: boxes), encoding: .utf8)!)
}
if args.contains("--text") {
  for l in lines {
    let ws = l["words"] as! [[String: Any]]
    print("  \(ws.map { $0["text"] as! String }.joined(separator: " "))  (\(String(format: "%.2f", ws.first!["confidence"] as! Double)))")
  }
}
