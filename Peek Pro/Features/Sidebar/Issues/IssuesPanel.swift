import SwiftUI

struct IssuesPanel: View {
    @Environment(AppModel.self) private var model
    @State private var selection: String?

    var body: some View {
        let issues = model.issues
        let errors = issues.filter { $0.severity == .error }
        let warnings = issues.filter { $0.severity == .warning }

        Group {
            if issues.isEmpty {
                ContentUnavailableView {
                    Label("No Issues", systemImage: "checkmark.seal")
                } description: {
                    Text("Failed requests, error statuses and slow responses show up here.")
                }
            } else {
                List(selection: $selection) {
                    if !errors.isEmpty {
                        Section("Errors") {
                            ForEach(errors) { IssueRow(issue: $0).tag($0.id) }
                        }
                    }
                    if !warnings.isEmpty {
                        Section("Warnings") {
                            ForEach(warnings) { issue in
                                IssueRow(issue: issue)
                                    .tag(issue.id)
                                    .selectionDisabled(issue.entryIDs.isEmpty)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .onChange(of: selection) { _, id in
            guard let id, let entryID = issues.first(where: { $0.id == id })?.latestEntryID else { return }
            model.reveal(entryID)
        }
        .onChange(of: model.selectedSessionID) {
            selection = nil
        }
    }
}

private struct IssueRow: View {
    let issue: SessionIssue

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: issue.severity == .error ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(
                    issue.severity == .error ? Color.white : Color.black,
                    issue.severity == .error ? Color(.statusFailure) : Color.yellow
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(issue.title)
                    .fontWeight(.medium)
                Text(issue.subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                if let lastSeen = issue.lastSeen {
                    Text(PeekFormat.time(lastSeen))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 4)
            if issue.count > 1 {
                CountBadge(count: issue.count)
            }
        }
        .padding(.vertical, 2)
        .help(issue.count > 1 ? "\(issue.count) times — selects the latest" : issue.subtitle)
    }
}

#Preview("Live") {
    IssuesPanel()
        .environment(AppModel.preview(.live))
        .frame(width: 280, height: 760)
}

#Preview("Dropped — Dark") {
    let model = AppModel.preview(.live)
    model.selectedSessionID = FixtureSessions.pixelSession.id
    return IssuesPanel()
        .environment(model)
        .frame(width: 280, height: 760)
        .preferredColorScheme(.dark)
}

#Preview("No Issues") {
    IssuesPanel()
        .environment(AppModel.preview(.waiting))
        .frame(width: 280, height: 400)
}
