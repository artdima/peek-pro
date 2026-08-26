import Foundation

/// What the protocol needs from a connection, so it can be driven without a socket.
protocol PeekRemoteChannel: AnyObject {
    var address: String { get }
    var onText: ((String) -> Void)? { get set }
    /// Called once, whichever side closed.
    var onClose: (() -> Void)? { get set }
    func send(_ text: String)
    func close()
}
