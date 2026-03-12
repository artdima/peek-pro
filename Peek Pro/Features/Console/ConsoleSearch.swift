import AppKit
import SwiftUI

nonisolated enum ConsoleSearchScope: String, CaseIterable, Identifiable, Sendable {
    case all
    case url
    case headers
    case body
    case errors

    var id: Self { self }

    var title: String {
        switch self {
        case .all: "All"
        case .url: "URL"
        case .headers: "Headers"
        case .body: "Body"
        case .errors: "Errors"
        }
    }
}

/// Mirrors `PeekSearchQuery`: case-insensitive, text bodies only and only their first part.
nonisolated struct ConsoleSearch: Sendable {
    static let bodyLimit = 64 * 1_024

    let text: String
    let scope: ConsoleSearchScope

    var query: String { text.trimmingCharacters(in: .whitespaces) }

    func matches(_ entry: PeekEntry) -> Bool {
        let query = query
        guard !query.isEmpty else { return true }
        let scopes: [ConsoleSearchScope] = scope == .all ? [.url, .headers, .body, .errors] : [scope]
        return scopes.contains { scope in
            switch scope {
            case .all: false
            case .url: entry.request.uri.absoluteString.localizedCaseInsensitiveContains(query)
            case .headers: headerText(entry).contains { $0.localizedCaseInsensitiveContains(query) }
            case .body: bodyText(entry).contains { $0.localizedCaseInsensitiveContains(query) }
            case .errors: errorText(entry).contains { $0.localizedCaseInsensitiveContains(query) }
            }
        }
    }

    private func headerText(_ entry: PeekEntry) -> [String] {
        let headers = entry.request.headers.entries + (entry.response?.headers.entries ?? [])
        return headers.map { "\($0.name): \($0.value)" }
    }

    private func bodyText(_ entry: PeekEntry) -> [String] {
        [entry.request.body, entry.response?.body].compactMap { body -> String? in
            switch body {
            case .text(let text, _, _): String(text.prefix(Self.bodyLimit))
            case .form(let fields, let files, _):
                (fields.map { "\($0.name)=\($0.value)" } + files.compactMap(\.filename)).joined(separator: "\n")
            default: nil
            }
        }
    }

    private func errorText(_ entry: PeekEntry) -> [String] {
        guard entry.isError else { return [] }
        return [entry.statusTitle, entry.failure?.message, entry.failure?.details].compactMap(\.self)
    }
}

extension EnvironmentValues {
    /// Text to mark in URLs while searching; empty when the search doesn't look at URLs.
    @Entry var searchHighlight = ""
}

extension AttributedString {
    mutating func highlight(_ query: String) {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        var lower = startIndex
        while lower < endIndex, let range = self[lower..<endIndex].range(of: query, options: .caseInsensitive) {
            self[range].backgroundColor = Color(nsColor: .findHighlightColor)
            self[range].foregroundColor = Color.black
            lower = range.upperBound
        }
    }
}
