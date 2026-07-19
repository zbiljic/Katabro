import AppKit

@MainActor
protocol BrowserPickerPresenting: AnyObject {
    var delegate: (any NSWindowDelegate)? { get set }

    func close()
    func presentNearPointer()
}

extension BrowserPickerPanel: BrowserPickerPresenting {}
