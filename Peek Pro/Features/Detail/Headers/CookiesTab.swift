import SwiftUI

struct CookiesTab: View {
    let entry: PeekEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                KeyValueSection(
                    title: "Request Cookies",
                    pairs: KeyValuePair.list(entry.request.headers.cookies.map { (name: $0.name, value: $0.value) }),
                    emptyText: "No cookies sent"
                )
                SetCookieSection(cookies: entry.response?.headers.setCookies ?? [])
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct SetCookieSection: View {
    let cookies: [PeekCookie]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Response Cookies")
                    .font(.headline)
                Text(cookies.count, format: .number)
                    .foregroundStyle(.tertiary)
            }
            if cookies.isEmpty {
                Text("No cookies set")
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(cookies.enumerated()), id: \.offset) { _, cookie in
                SetCookieCard(cookie: cookie)
            }
        }
    }
}

private struct SetCookieCard: View {
    let cookie: PeekCookie

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(cookie.name)
                    .fontWeight(.semibold)
                Text("=")
                    .foregroundStyle(.tertiary)
                if cookie.value.contains("*****") {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .help("Redacted on the device")
                }
                Text(cookie.value)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .truncationMode(.middle)
                Spacer(minLength: 8)
                CopyButton(text: "\(cookie.name)=\(cookie.value)", title: "Copy Cookie")
            }
            .font(.callout.monospaced())

            FlowLayout(spacing: 6) {
                ForEach(attributes, id: \.self) { attribute in
                    Text(attribute)
                        .font(.caption)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }

    private var attributes: [String] {
        var result: [String] = []
        if let domain = cookie.domain { result.append("Domain \(domain)") }
        if let path = cookie.path { result.append("Path \(path)") }
        if let maxAge = cookie.maxAge {
            result.append("Max-Age \(Duration.seconds(maxAge).formatted(.units(allowed: [.days, .hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 2)))")
        }
        if let expires = cookie.expires { result.append("Expires \(expires)") }
        if cookie.maxAge == nil && cookie.expires == nil { result.append("Session") }
        if cookie.isSecure { result.append("Secure") }
        if cookie.isHttpOnly { result.append("HttpOnly") }
        if let sameSite = cookie.sameSite { result.append("SameSite \(sameSite)") }
        return result
    }
}

#Preview("Login") {
    CookiesTab(entry: Fixtures.entry("f01"))
        .frame(width: 900, height: 500)
}

#Preview("Profile — Dark") {
    CookiesTab(entry: Fixtures.entry("f02"))
        .frame(width: 900, height: 400)
        .preferredColorScheme(.dark)
}
