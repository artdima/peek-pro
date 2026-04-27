import AppKit
import SwiftUI

/// Shown instead of the list when a file can't be read at all.
struct FileFailureView: View {
    @Environment(AppModel.self) private var model
    let file: PeekSessionFile

    var body: some View {
        ContentUnavailableView {
            Label("Can't Open “\(file.name)”", systemImage: "doc.badge.xmark")
        } description: {
            Text(explanation)
        } actions: {
            HStack {
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([file.url])
                }
                Button("Close File") { model.closeFile(file.id) }
            }
        }
    }

    private var explanation: String {
        switch file.failure {
        case .unsupportedFormat(let version):
            "It uses session format v\(version), written by Peek \(file.info.peekVersion). "
                + "This Peek Pro reads format v\(PeekSessionFile.supportedFormatVersion). "
                + "Save the session again with a current version of Peek."
        case nil:
            ""
        }
    }
}

/// Warnings that a readable file still carries: a newer format, lines that were skipped.
struct FileBanners: View {
    let file: PeekSessionFile

    var body: some View {
        VStack(spacing: 0) {
            if file.isNewerFormat {
                FileBanner(
                    symbol: "sparkles",
                    title: "Saved by a newer Peek",
                    detail: "Format v\(file.formatVersion) from Peek \(file.info.peekVersion). Fields this version doesn't know are left out."
                )
            }
            if file.skippedLines > 0 {
                FileBanner(
                    symbol: "exclamationmark.triangle.fill",
                    title: "\(file.skippedLines) \(file.skippedLines == 1 ? "line" : "lines") couldn't be read",
                    detail: "The file may be cut short or edited by hand. Everything else is shown."
                )
            }
        }
    }
}

private struct FileBanner: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .fontWeight(.semibold)
                    Text(detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.yellow.opacity(0.1))
            Divider()
        }
    }
}

#Preview("Legacy") {
    FileFailureView(file: FixtureSessions.legacyFile)
        .environment(AppModel.preview(.file))
        .frame(width: 800, height: 400)
}

#Preview("Warnings — Dark") {
    VStack(spacing: 0) {
        FileBanners(file: FixtureSessions.futureFile)
        FileBanners(file: FixtureSessions.bugReport)
    }
    .frame(width: 800)
    .preferredColorScheme(.dark)
}
