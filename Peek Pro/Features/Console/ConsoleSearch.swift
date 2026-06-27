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

    var scopes: Set<PeekSearchScope> {
        switch self {
        case .all: Set(PeekSearchScope.allCases)
        case .url: [.url]
        case .headers: [.headers]
        case .body: [.requestBody, .responseBody]
        case .errors: [.error]
        }
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
