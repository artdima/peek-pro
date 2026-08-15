import Foundation
import Testing
@testable import Peek_Pro

@Suite("Remote frames")
struct PeekRemoteFrameTests {
    private func frame(_ name: String) throws -> PeekRemoteFrame {
        try PeekRemoteFrame(text: try Spec.frameText(name))
    }

    @Test("reads every reference frame and writes it back as Peek wrote it")
    func referenceFrames() throws {
        let manifest = try Spec.frames()
        #expect(manifest.count >= 16)
        for (name, expectation) in manifest {
            let text = try Spec.frameText(name)
            let read = try PeekRemoteFrame(text: text)
            if expectation.ignored == true {
                #expect(read == .unknown(type: expectation.type), "\(name)")
            } else if let same = expectation.sameAs {
                #expect(read == (try frame(same)), "\(name)")
            } else {
                #expect(read.text == text, "\(name)")
            }
            #expect(read.json["type"]?.encoded() == "\"\(expectation.type)\"", "\(name)")
        }
    }

    @Test("reads what each frame says")
    func contents() throws {
        guard case .hello(let hello) = try frame("hello.json") else {
            Issue.record("hello.json is not a hello")
            return
        }
        #expect(hello.protocolVersion == PeekRemoteProtocol.version)
        #expect(hello.token == "k7Qx2mP9")
        #expect(hello.sessionID == "3f2a9c1e0b7d4e56a8c1f0e2d3b4a596")
        #expect(hello.info.name == "Peek fixtures")
        #expect(hello.info.platform == .iOS)
        #expect(hello.info.osVersion == "18.0")

        guard case .entryAdded(let started) = try frame("entry-add.json") else {
            Issue.record("entry-add.json is not an added entry")
            return
        }
        #expect(started.state == .pending)
        #expect(started.request.body == .remote(size: 18, contentType: .json))
        guard case .entryUpdated(let completed) = try frame("entry-update.json") else {
            Issue.record("entry-update.json is not an updated entry")
            return
        }
        #expect(completed.id == started.id)
        #expect(completed.statusCode == 201)

        #expect(try frame("entry-remove.json") == .entryRemoved(PeekId("e1")))
        #expect(try frame("welcome.json") == .welcome(serverName: "Peek Pro", serverVersion: "1.0.0"))
        #expect(try frame("synced.json") == .synced(count: 42))
        #expect(try frame("dropped.json") == .dropped(count: 37))
        #expect(try frame("body-request.json") == .bodyRequest(requestID: "7", entryID: PeekId("e1"), side: .response))
        #expect(try frame("body-error.json") == .bodyError(requestID: "8", error: .notFound, message: "No call e404 on this device."))
        guard case .bodyResponse("7", let body) = try frame("body-response.json") else {
            Issue.record("body-response.json is not a body")
            return
        }
        #expect(body == .text(#"{"id":9,"status":"new"}"#, contentType: .json))
    }

    @Test("reads unknown values as their fallbacks and ignores unknown keys")
    func leniency() throws {
        #expect(try PeekRemoteFrame(text: #"{"type":"denied","reason":"maintenance","message":"x"}"#) == .denied(.other, message: "x"))
        #expect(try PeekRemoteFrame(text: #"{"type":"bodyResponse","requestId":"1","error":"gone"}"#)
            == .bodyError(requestID: "1", error: .failed, message: nil))
        #expect(try PeekRemoteFrame(text: #"{"type":"welcome","protocolVersion":1,"server":null}"#) == .welcome())
        #expect(try PeekRemoteFrame(text: #"{"type":"pong","extra":{"deep":[1]}}"#) == .pong)
        #expect(try PeekRemoteFrame(text: #"{"type":"hologram"}"#) == .unknown(type: "hologram"))
    }

    @Test("refuses what isn't a frame", arguments: [
        "not json",
        "[1, 2]",
        #"{"kind":"hello"}"#,
        #"{"type":7}"#,
        #"{"type":"synced"}"#,
        #"{"type":"entry","op":"move","id":"e1"}"#,
        #"{"type":"entry","op":"add"}"#,
        #"{"type":"bodyRequest","requestId":"1","id":"e1","side":"both"}"#,
        #"{"type":"hello","protocolVersion":1,"sessionId":"s"}"#,
    ])
    func refuses(_ text: String) {
        #expect(throws: (any Error).self) { try PeekRemoteFrame(text: text) }
    }

    @Test("writes what the desktop sends, leaving out what it didn't say")
    func writing() {
        #expect(PeekRemoteFrame.welcome().text == #"{"type":"welcome","protocolVersion":1}"#)
        #expect(PeekRemoteFrame.welcome(serverName: "Peek Pro").text == #"{"type":"welcome","protocolVersion":1,"server":{"name":"Peek Pro"}}"#)
        #expect(PeekRemoteFrame.bodyError(requestID: "1", error: .notHeld, message: nil).text
            == #"{"type":"bodyResponse","requestId":"1","error":"notHeld"}"#)
        #expect(PeekRemoteFrame.ping.text == #"{"type":"ping"}"#)
    }

    @Test("welcomes the right token and version, and says which side to update otherwise")
    func check() throws {
        guard case .hello(let hello) = try frame("hello.json") else { return }
        #expect(PeekRemoteProtocol.check(hello, token: "k7Qx2mP9") == nil)
        #expect(PeekRemoteProtocol.check(hello, token: nil) == nil)

        guard case .denied(let reason, _) = PeekRemoteProtocol.check(hello, token: "k7Qx2mP0") else {
            Issue.record("a wrong token was welcomed")
            return
        }
        #expect(reason == .token)
        var missing = hello
        missing.token = nil
        #expect(PeekRemoteProtocol.check(missing, token: "k7Qx2mP9") == .denied(.token, message: "The token does not match the one the desktop shows."))

        var newer = hello
        newer.protocolVersion = 2
        newer.token = "wrong"
        guard case .denied(.protocolVersion, let message) = PeekRemoteProtocol.check(newer, token: "k7Qx2mP9") else {
            Issue.record("a newer protocol was welcomed")
            return
        }
        #expect(message.contains("Update the desktop"))
        var older = hello
        older.protocolVersion = 0
        guard case .denied(_, let olderMessage) = PeekRemoteProtocol.check(older, token: nil) else { return }
        #expect(olderMessage.contains("Update Peek in the app"))
        newer.token = "k7Qx2mP9"
        #expect(PeekRemoteProtocol.check(newer, token: "k7Qx2mP9", newest: 2) == nil)
    }
}
