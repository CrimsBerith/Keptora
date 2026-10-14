import Foundation

/// Turns an error message into an alert title and detail, so the title says what happened
/// instead of a generic "Something went wrong".
public enum AlertText {
    /// The first sentence becomes the title; anything after it becomes the detail.
    /// Messages without a sentence break are used as the title alone.
    public static func split(_ message: String) -> (title: String, detail: String?) {
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        for terminator in [". ", "! ", "? "] {
            if let range = text.range(of: terminator) {
                let title = String(text[..<range.lowerBound]) + String(terminator.prefix(1))
                let detail = String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                return (title, detail.isEmpty ? nil : detail)
            }
        }
        return (text, nil)
    }
}
