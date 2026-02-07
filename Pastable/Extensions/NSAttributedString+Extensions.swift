import SwiftUI

extension NSAttributedString {
    var effectiveBackgroundColor: Color? {
        guard length > 0 else { return nil }
        
        // Check the attributes of the first character
        // We assume the background style is consistent for the block usually (like a code block)
        let attributes = attributes(at: 0, effectiveRange: nil)
        
        if let color = attributes[.backgroundColor] as? NSColor {
            // Ignore clear or fully transparent colors
            if color.alphaComponent > 0 {
                 return Color(nsColor: color)
            }
        }
        
        // Also check for document-wide attributes if present (less common in simple copy, but possible)
        if let docColor = apiDocumentColor {
             return Color(nsColor: docColor)
        }
        
        return nil
    }
    
    // Helper for document attribute if stored (RTF import sometimes sets this separately)
    private var apiDocumentColor: NSColor? {
        // Implementation depends on how it was initialized, often handled via documentAttributes pointer
        // For simple attribute string from pasteboard, scanning attributes is safer.
        return nil
    }
}
