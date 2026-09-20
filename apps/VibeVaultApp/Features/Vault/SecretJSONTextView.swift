import AppKit
import SwiftUI

/// Monospaced NSTextView that keeps a real height inside macOS Form sections.
struct SecretJSONTextView: NSViewRepresentable {
    @Binding var text: String
    var minHeight: CGFloat = 180

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> IntrinsicScrollView {
        let scroll = IntrinsicScrollView()
        scroll.minHeight = minHeight
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        scroll.setContentHuggingPriority(.required, for: .vertical)
        scroll.setContentCompressionResistancePriority(.required, for: .vertical)

        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        textView.textContainerInset = NSSize(width: 6, height: 6)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.minSize = NSSize(width: 0, height: minHeight)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.backgroundColor = .clear
        textView.string = text
        textView.setAccessibilityLabel("JSON value")
        context.coordinator.textView = textView
        scroll.documentView = textView
        return scroll
    }

    func updateNSView(_ scroll: IntrinsicScrollView, context: Context) {
        scroll.minHeight = minHeight
        scroll.invalidateIntrinsicContentSize()
        guard let textView = scroll.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
    }

    final class IntrinsicScrollView: NSScrollView {
        var minHeight: CGFloat = 180

        override var intrinsicContentSize: NSSize {
            NSSize(width: NSView.noIntrinsicMetric, height: minHeight)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        weak var textView: NSTextView?

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? NSTextView else { return }
            text.wrappedValue = view.string
        }
    }
}
