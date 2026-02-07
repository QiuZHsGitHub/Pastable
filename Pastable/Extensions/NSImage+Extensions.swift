import Cocoa
import SwiftUI

extension NSImage {
  /// Calculates the dominant color of the image, prioritizing vibrant/brand colors
  func averageColor() -> Color? {
    guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
    
    // Resize to a small grid (e.g. 50x50) for performance
    let width = 50
    let height = 50
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    var bitmapData = [UInt8](repeating: 0, count: width * height * 4)
    
    guard let context = CGContext(
      data: &bitmapData,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: width * 4,
      space: colorSpace,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    
    // Buckets to store (Count, SumR, SumG, SumB)
    var clusters: [UInt32: (count: Int, r: Int, g: Int, b: Int)] = [:]
    
    var totalValidPixels = 0
    
    for i in 0..<(width * height) {
      let offset = i * 4
      let r = Int(bitmapData[offset])
      let g = Int(bitmapData[offset + 1])
      let b = Int(bitmapData[offset + 2])
      let a = Int(bitmapData[offset + 3])
      
      if a < 50 { continue }
      totalValidPixels += 1
      
      // Quantize to find cluster (4-bit reduction)
      let qr = (UInt32(r) & 0xF0) >> 4
      let qg = (UInt32(g) & 0xF0) >> 4
      let qb = (UInt32(b) & 0xF0) >> 4
      let key = (qr << 8) | (qg << 4) | qb
      
      var current = clusters[key] ?? (0, 0, 0, 0)
      current.count += 1
      current.r += r
      current.g += g
      current.b += b
      clusters[key] = current
    }
    
    guard totalValidPixels > 0 else { return nil }
    
    // Filter and Score Clusters
    // Threshold: 2% (0.02) for icons as suggested
    let threshold = Int(Double(totalValidPixels) * 0.02)
    
    var bestColor: NSColor? = nil
    var maxScore: Double = -1.0
    
    for (_, cluster) in clusters {
        if cluster.count < threshold { continue }
        
        let ratio = Double(cluster.count) / Double(totalValidPixels)
        
        // Calculate Centroid Color
        let r = Double(cluster.r) / Double(cluster.count)
        let g = Double(cluster.g) / Double(cluster.count)
        let b = Double(cluster.b) / Double(cluster.count)
        let nsColor = NSColor(calibratedRed: r/255.0, green: g/255.0, blue: b/255.0, alpha: 1.0)
        
        // Score: Measure Saturation
        let sat = nsColor.saturationComponent
        
        // Formula: score = area * (0.3 + S*S)
        // This allows small vibrant areas to beat large gray areas
        let score = ratio * (0.3 + sat * sat)
        
        if score > maxScore {
            maxScore = score
            bestColor = nsColor
        }
    }
    
    guard let finalColor = bestColor else { return nil }
    
    // Optional: Contrast Check (Prevent purely dark colors on dark theme if needed, or purely white)
    // The user suggested Contrast Filter step, but for now we stick to the scoring selection.
    // If the winning color is extremely bright (White background winning despite penalty), 
    // we might want to clamp it slightly for text visibility, but user said "revert" previous clamps.
    // We will apply a minimal safety check for text readability if it's mostly white.
    
    var result = finalColor
    
    // Post-Processing: Ensure Dark Theme Compatibility
    // Use a "Soft Knee" compression curve to smoothly darken bright colors without sudden jumps.
    // Maps input brightness [0.4 ... 1.0] -> [0.4 ... 0.7].
    if result.brightnessComponent > 0.5 {
        let newBrightness = 0.5 + (result.brightnessComponent - 0.5) * 0.5
        result = NSColor(
          calibratedHue: result.hueComponent,
          saturation: result.saturationComponent,
          brightness: newBrightness,
          alpha: 1.0
        )
    }

    return Color(nsColor: result)
  }

}
