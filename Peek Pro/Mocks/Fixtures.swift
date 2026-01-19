import Foundation

/// Calls of one app session, in the order they started. Every state the UI has to draw appears here at least once.
enum Fixtures {
    static let start = Date(timeIntervalSinceReferenceDate: 811_868_099.803)

    static let userAgent = "AcmeShop/3.4.0 (iPhone; iOS 26.0) Dart/3.9 (dart:io)"

    static func requestHeaders(_ extra: [(String, String)] = [], authorized: Bool = true) -> PeekHeaders {
        var pairs = [("Accept", "application/json"), ("Accept-Encoding", "gzip"), ("User-Agent", userAgent)]
        if authorized { pairs.append(("Authorization", "*****")) }
        return PeekHeaders(pairs + extra)
    }

    static func responseHeaders(
        _ contentType: String,
        length: Int? = nil,
        _ extra: [(String, String)] = []
    ) -> PeekHeaders {
        var pairs = [
            ("Content-Type", contentType),
            ("Date", "Wed, 23 Sep 2026 14:55:01 GMT"),
            ("Server", "nginx/1.27.2"),
            ("X-Request-Id", "b1f0c2d6-4e8a-4f39-9d3e-2c5b8f1a7e90"),
        ]
        if let length { pairs.insert(("Content-Length", "\(length)"), at: 1) }
        return PeekHeaders(pairs + extra)
    }

    static func jsonHeaders(_ body: String, _ extra: [(String, String)] = []) -> PeekHeaders {
        responseHeaders("application/json; charset=utf-8", length: body.utf8.count, extra)
    }

    static func entry(
        _ id: String,
        _ method: String,
        _ url: String,
        at offset: TimeInterval,
        took milliseconds: Double? = nil,
        status: Int? = nil,
        requestHeaders: PeekHeaders? = nil,
        requestBody: PeekBody = .empty,
        responseHeaders: PeekHeaders = .empty,
        responseBody: PeekBody = .empty,
        redirects: [PeekRedirect] = [],
        failure: PeekFailure? = nil,
        source: String = "dio",
        isPinned: Bool = false,
        timings: PeekTimings? = nil
    ) -> PeekEntry {
        let startedAt = start.addingTimeInterval(offset)
        let response = status.map {
            PeekResponse(
                statusCode: $0,
                statusMessage: PeekHTTPStatus.reasonPhrase(for: $0),
                headers: responseHeaders,
                body: responseBody,
                redirects: redirects
            )
        }
        let isFinished = response != nil || failure != nil
        return PeekEntry(
            id: PeekId(id),
            request: PeekRequest(
                method: method,
                uri: URL(string: url)!,
                headers: requestHeaders ?? Self.requestHeaders(),
                body: requestBody
            ),
            startedAt: startedAt,
            source: source,
            response: response,
            failure: failure,
            completedAt: isFinished ? startedAt.addingTimeInterval((milliseconds ?? 0) / 1000) : nil,
            isPinned: isPinned,
            timings: timings
        )
    }

    static let session: [PeekEntry] = [
        entry(
            "f01", "POST", "https://auth.acme.dev/v1/login?scopes=profile,orders",
            at: 0, took: 426.9, status: 200,
            requestHeaders: requestHeaders([("Content-Type", "application/json")], authorized: false),
            requestBody: .json(FixtureBodies.loginRequest),
            responseHeaders: jsonHeaders(FixtureBodies.loginResponse, [
                ("Set-Cookie", "session=*****; Path=/; Domain=acme.dev; Max-Age=86400; Secure; HttpOnly; SameSite=Lax"),
                ("Set-Cookie", "locale=en-PT; Path=/; Expires=Thu, 23 Sep 2027 14:55:00 GMT"),
                ("Cache-Control", "no-store"),
            ]),
            responseBody: .json(FixtureBodies.loginResponse),
            isPinned: true,
            timings: PeekTimings(
                blocked: .milliseconds(7.9), dns: .milliseconds(19.5), connect: .milliseconds(129.9),
                ssl: .milliseconds(107.5), send: .milliseconds(4.2), wait: .milliseconds(211.5),
                receive: .milliseconds(52.9)
            )
        ),
        entry(
            "f02", "GET", "https://api.acme.dev/v1/profile",
            at: 1.63, took: 526.9, status: 200,
            requestHeaders: requestHeaders([("Cookie", "session=*****; locale=en-PT")]),
            responseHeaders: jsonHeaders(FixtureBodies.profile, [("ETag", "W/\"a1c9-18f\""), ("Cache-Control", "private, max-age=60")]),
            responseBody: .json(FixtureBodies.profile)
        ),
        entry(
            "f03", "GET", "https://api.acme.dev/v1/users/valdo",
            at: 1.63, took: 226.9, status: 404,
            responseHeaders: jsonHeaders(FixtureBodies.userNotFound),
            responseBody: .json(FixtureBodies.userNotFound)
        ),
        entry(
            "f04", "GET", "https://cdn.acme.dev/avatars/octocat.png",
            at: 3.31, took: 226.9, status: 200,
            requestHeaders: requestHeaders([("Accept", "image/*")], authorized: false),
            responseHeaders: responseHeaders("image/png", length: FixtureBodies.avatarPNG.count, [("Cache-Control", "public, max-age=31536000")]),
            responseBody: .bytes(FixtureBodies.avatarPNG, contentType: PeekMediaType("image", "png")),
            source: "http"
        ),
        entry(
            "f05", "GET", "https://api.acme.dev/v1/catalog?page=1&per_page=2400&sort=popular",
            at: 3.31, took: 4_465, status: 200,
            responseHeaders: jsonHeaders(FixtureBodies.catalog),
            responseBody: .json(FixtureBodies.catalog)
        ),
        entry(
            "f06", "GET", "https://api.acme.dev/v1/feed?since=2026-09-22",
            at: 5.1, took: 1_327, status: 200,
            responseHeaders: responseHeaders("application/json", length: 3_250_000),
            responseBody: .json(FixtureBodies.truncatedFeed, size: 3_250_000)
        ),
        entry(
            "f07", "POST", "https://api.acme.dev/v1/cart/items",
            at: 5.1, took: 303.8, status: 201,
            requestHeaders: requestHeaders([("Content-Type", "application/json")]),
            requestBody: .json(FixtureBodies.cartItemRequest),
            responseHeaders: jsonHeaders(FixtureBodies.cartItemResponse, [("Location", "/v1/cart/items/42")]),
            responseBody: .json(FixtureBodies.cartItemResponse),
            source: "chopper"
        ),
        entry(
            "f08", "DELETE", "https://api.acme.dev/v1/cart/items/41",
            at: 6.9, took: 180.2, status: 204,
            responseHeaders: responseHeaders("text/plain"),
            source: "chopper"
        ),
        entry(
            "f09", "GET", "http://acme.dev/promo",
            at: 8.4, took: 612.4, status: 200,
            requestHeaders: requestHeaders([("Accept", "text/html")], authorized: false),
            responseHeaders: responseHeaders("text/html; charset=utf-8", length: FixtureBodies.promoPage.utf8.count),
            responseBody: .text(FixtureBodies.promoPage, contentType: .html),
            redirects: [
                PeekRedirect(statusCode: 301, method: "GET", location: URL(string: "https://acme.dev/promo")!),
                PeekRedirect(statusCode: 302, method: "GET", location: URL(string: "https://www.acme.dev/promo")!),
            ]
        ),
        entry(
            "f10", "PUT", "https://api.acme.dev/v1/profile/avatar",
            at: 10.2, took: 2_213, status: 500,
            requestHeaders: requestHeaders([("Content-Type", "image/png")]),
            requestBody: .bytes(FixtureBodies.avatarPNG, contentType: PeekMediaType("image", "png")),
            responseHeaders: jsonHeaders(FixtureBodies.serverError),
            responseBody: .json(FixtureBodies.serverError)
        ),
        entry(
            "f11", "GET", "https://api.acme.dev/v1/recommendations",
            at: 11.0, took: 94.6, status: 503,
            responseHeaders: jsonHeaders(FixtureBodies.unavailable, [("Retry-After", "30")]),
            responseBody: .json(FixtureBodies.unavailable),
            source: "talker/dio"
        ),
        entry(
            "f12", "GET", "https://api.acme.dev/v1/orders?status=open",
            at: 12.4, took: 30_000,
            failure: PeekFailure(
                kind: .timeout,
                message: "The request connection took longer than 0:00:30.000000 and it was aborted.",
                details: "DioException [connection timeout]: raise RequestOptions.connectTimeout or check the server.",
                stackTrace: FixtureBodies.timeoutStackTrace
            ),
            source: "talker/dio"
        ),
        entry(
            "f13", "POST", "https://events.acme.dev/v1/batch",
            at: 13.0, took: 12.3,
            requestHeaders: requestHeaders([("Content-Type", "application/json")]),
            requestBody: .json("{\n  \"events\": [\n    { \"name\": \"screen_view\", \"screen\": \"catalog\" }\n  ]\n}"),
            failure: PeekFailure(
                kind: .connection,
                message: "Failed host lookup: 'events.acme.dev'",
                details: "SocketException: Failed host lookup: 'events.acme.dev' (OS Error: nodename nor servname provided, or not known, errno = 8)",
                stackTrace: FixtureBodies.connectionStackTrace
            ),
            source: "http"
        ),
        entry(
            "f14", "GET", "https://legacy.acme.dev/v1/status",
            at: 14.2, took: 188.0,
            failure: PeekFailure(
                kind: .badCertificate,
                message: "The certificate for legacy.acme.dev is not trusted",
                details: "HandshakeException: Handshake error in client (OS Error: CERTIFICATE_VERIFY_FAILED: certificate has expired(handshake.cc:393))"
            ),
            source: "http"
        ),
        entry(
            "f15", "GET", "https://api.acme.dev/v1/search?q=sneak",
            at: 15.0, took: 88.1,
            failure: PeekFailure(kind: .cancelled, message: "The request was cancelled: a newer search replaced it."),
            source: "dio"
        ),
        entry(
            "f16", "POST", "https://api.acme.dev/v1/payments",
            at: 16.8, took: 734.0, status: 422,
            requestHeaders: requestHeaders([("Content-Type", "application/json"), ("Idempotency-Key", "8f14e45f-ceea-467f-a0e6-5b7d1d9a2c10")]),
            requestBody: .json(FixtureBodies.paymentRequest),
            responseHeaders: jsonHeaders(FixtureBodies.paymentErrors),
            responseBody: .json(FixtureBodies.paymentErrors),
            failure: PeekFailure(
                kind: .badResponse,
                message: "This exception was thrown because the response has a status code of 422 and RequestOptions.validateStatus was configured to throw for this status code.",
                details: "DioException [bad response]"
            )
        ),
        entry(
            "f17", "GET", "https://api.acme.dev/v1/notifications?unread=true",
            at: 68.2
        ),
        entry(
            "f18", "POST", "https://uploads.acme.dev/v1/photos",
            at: 69.5,
            requestHeaders: requestHeaders([("Content-Type", "multipart/form-data; boundary=dart-http-boundary-Zq7s2")]),
            requestBody: .form(
                fields: [PeekFormField("album", "returns")],
                files: [PeekFormFile("photo", filename: "IMG_2041.HEIC", contentType: PeekMediaType("image", "heic"), size: 3_481_220)],
                contentType: PeekMediaType("multipart", "form-data", parameters: ["boundary": "dart-http-boundary-Zq7s2"])
            ),
            source: "http"
        ),
        entry(
            "f19", "POST", "https://uploads.acme.dev/v1/documents",
            at: 18.0, took: 2_213, status: 201,
            requestHeaders: requestHeaders([("Content-Type", "multipart/form-data; boundary=dart-http-boundary-Kf93a")]),
            requestBody: .form(
                fields: [PeekFormField("title", "September receipt"), PeekFormField("folder", "expenses")],
                files: [
                    PeekFormFile("file", filename: "receipt-2026-09.pdf", contentType: PeekMediaType("application", "pdf"), size: 482_113),
                    PeekFormFile("thumbnail", filename: "receipt.jpg", contentType: PeekMediaType("image", "jpeg"), size: 24_310),
                ],
                contentType: PeekMediaType("multipart", "form-data", parameters: ["boundary": "dart-http-boundary-Kf93a"])
            ),
            responseHeaders: jsonHeaders(FixtureBodies.documentCreated),
            responseBody: .json(FixtureBodies.documentCreated),
            source: "http"
        ),
        entry(
            "f20", "POST", "https://auth.acme.dev/oauth/token",
            at: 20.4, took: 245.3, status: 200,
            requestHeaders: requestHeaders([("Content-Type", "application/x-www-form-urlencoded")], authorized: false),
            requestBody: .text(FixtureBodies.tokenRequest, contentType: .formUrlEncoded),
            responseHeaders: jsonHeaders(FixtureBodies.tokenResponse, [("Cache-Control", "no-store")]),
            responseBody: .json(FixtureBodies.tokenResponse)
        ),
        entry(
            "f21", "GET", "https://api.acme.dev/v1/stock/snapshot",
            at: 22.0, took: 158.7, status: 200,
            requestHeaders: requestHeaders([("Accept", "application/x-protobuf")]),
            responseHeaders: responseHeaders("application/x-protobuf", length: FixtureBodies.protobuf.count),
            responseBody: .bytes(FixtureBodies.protobuf, contentType: PeekMediaType("application", "x-protobuf")),
            source: "http"
        ),
        entry(
            "f22", "GET", "https://stream.acme.dev/v1/live-prices",
            at: 23.1, took: 41_220, status: 200,
            requestHeaders: requestHeaders([("Accept", "text/event-stream")]),
            responseHeaders: responseHeaders("text/event-stream", [("Cache-Control", "no-cache")]),
            responseBody: .unavailable(.streamed, contentType: PeekMediaType("text", "event-stream"))
        ),
        entry(
            "f23", "GET", "https://api.acme.dev/v1/export/orders.zip",
            at: 25.7, took: 6_720, status: 200,
            requestHeaders: requestHeaders([("Accept", "application/zip")]),
            responseHeaders: responseHeaders("application/zip", length: 48_211_730, [("Content-Disposition", "attachment; filename=\"orders.zip\"")]),
            responseBody: .unavailable(.tooLarge, contentType: PeekMediaType("application", "zip"), size: 48_211_730)
        ),
        entry(
            "f24", "GET", "https://api.acme.dev/v1/config",
            at: 27.3, took: 112.9, status: 200,
            responseHeaders: responseHeaders("application/json", length: 18_432),
            responseBody: .remote(size: 18_432, contentType: .json)
        ),
        entry(
            "f25", "GET",
            "https://maps.acme.dev/v2/tiles/render?bbox=-9.1604%2C38.7071%2C-9.1307%2C38.7223&zoom=15&layers=stores%2Cpickup-points%2Ctraffic&style=light&scale=2&format=png&session=4f1c2a9e7b3d4c8f&lang=en",
            at: 28.9, took: 842.5, status: 200,
            requestHeaders: requestHeaders([("Accept", "image/png")], authorized: false),
            responseHeaders: responseHeaders("image/png", length: 391_804),
            responseBody: .remote(size: 391_804, contentType: PeekMediaType("image", "png")),
            source: "http"
        ),
        entry(
            "f26", "GET", "https://api.acme.dev/v1/profile",
            at: 31.2, took: 64.0, status: 304,
            requestHeaders: requestHeaders([("If-None-Match", "W/\"a1c9-18f\"")]),
            responseHeaders: responseHeaders("application/json", [("ETag", "W/\"a1c9-18f\"")])
        ),
        entry(
            "f27", "HEAD", "https://cdn.acme.dev/bundles/web-checkout.js",
            at: 32.0, took: 38.4, status: 200,
            requestHeaders: requestHeaders([("Accept", "*/*")], authorized: false),
            responseHeaders: responseHeaders("application/javascript", length: 284_117, [("Cache-Control", "public, max-age=604800")]),
            source: "http"
        ),
        entry(
            "f28", "POST", "https://api.acme.dev/graphql",
            at: 34.6, took: 1_904, status: 200,
            requestHeaders: requestHeaders([("Content-Type", "application/json")]),
            requestBody: .json(FixtureBodies.graphqlRequest),
            responseHeaders: jsonHeaders(FixtureBodies.graphqlResponse),
            responseBody: .json(FixtureBodies.graphqlResponse),
            source: "talker/dio"
        ),
        entry(
            "f29", "GET", "https://api.acme.dev/v1/products/1842",
            at: 36.0, took: 45.2, status: 200,
            responseHeaders: jsonHeaders(FixtureBodies.product, [("Cache-Control", "public, max-age=300"), ("Age", "118")]),
            responseBody: .json(FixtureBodies.product)
        ),
        entry(
            "f30", "GET", "https://api.acme.dev/v1/products/1842/reviews?page=2",
            at: 36.1, took: 310.6, status: 200,
            responseHeaders: jsonHeaders(FixtureBodies.reviews),
            responseBody: .json(FixtureBodies.reviews),
            timings: PeekTimings(send: .milliseconds(1.1), wait: .milliseconds(287.3), receive: .milliseconds(22.2))
        ),
        entry(
            "f31", "POST", "https://events.acme.dev/v1/batch",
            at: 40.0, took: 61.9, status: 202,
            requestHeaders: requestHeaders([("Content-Type", "application/json")]),
            requestBody: .json("{\n  \"events\": [\n    { \"name\": \"add_to_cart\", \"product_id\": 1842 },\n    { \"name\": \"screen_view\", \"screen\": \"cart\" }\n  ]\n}"),
            responseHeaders: responseHeaders("text/plain", length: 0),
            source: "http"
        ),
        entry(
            "f32", "GET", "https://api.acme.dev/v1/orders/ord_8Hq2",
            at: 43.5, took: 120.0, status: 401,
            responseHeaders: jsonHeaders(FixtureBodies.unauthorized, [("WWW-Authenticate", "Bearer error=\"invalid_token\"")]),
            responseBody: .json(FixtureBodies.unauthorized)
        ),
        entry(
            "f33", "GET", "https://api.acme.dev/v1/admin/stats",
            at: 45.0, took: 98.3, status: 403,
            responseHeaders: jsonHeaders(FixtureBodies.forbidden),
            responseBody: .json(FixtureBodies.forbidden)
        ),
        entry(
            "f34", "GET", "https://api.acme.dev/v1/feature-flags",
            at: 46.2, took: 77.5, status: 200,
            responseHeaders: jsonHeaders(FixtureBodies.featureFlags),
            responseBody: .json(FixtureBodies.featureFlags),
            source: "chopper",
            isPinned: true
        ),
        entry(
            "f35", "PUT", "https://api.acme.dev/v1/settings",
            at: 50.8, took: 210.4, status: 200,
            requestHeaders: requestHeaders([("Content-Type", "application/json")]),
            requestBody: .json(FixtureBodies.settingsRequest),
            responseHeaders: jsonHeaders(FixtureBodies.settingsRequest),
            responseBody: .json(FixtureBodies.settingsRequest),
            source: "chopper"
        ),
        entry(
            "f36", "GET", "https://api.acme.dev/v1/search?q=sneakers&page=3",
            at: 53.3, took: 33.7, status: 429,
            responseHeaders: jsonHeaders(FixtureBodies.rateLimited, [("Retry-After", "12"), ("X-RateLimit-Remaining", "0")]),
            responseBody: .json(FixtureBodies.rateLimited)
        ),
        entry(
            "f37", "GET", "https://www.acme.dev/help/faq",
            at: 57.9, took: 402.8, status: 200,
            requestHeaders: requestHeaders([("Accept", "text/html")], authorized: false),
            responseHeaders: responseHeaders("text/html; charset=utf-8", length: FixtureBodies.faqPage.utf8.count),
            responseBody: .text(FixtureBodies.faqPage, contentType: .html),
            source: "http"
        ),
        entry(
            "f38", "GET", "https://www.acme.dev/sitemap.xml",
            at: 60.1, took: 150.0, status: 200,
            requestHeaders: requestHeaders([("Accept", "application/xml")], authorized: false),
            responseHeaders: responseHeaders("application/xml", length: FixtureBodies.sitemap.utf8.count),
            responseBody: .text(FixtureBodies.sitemap, contentType: PeekMediaType("application", "xml")),
            source: "http"
        ),
    ]

    static func entry(_ id: String) -> PeekEntry {
        session.first { $0.id.value == id }!
    }

    /// Finished calls that the live scenario replays as new traffic.
    static let liveTemplates: [PeekEntry] = ["f02", "f29", "f30", "f07", "f03", "f34", "f31", "f11", "f20", "f04"]
        .map { Fixtures.entry($0) }

    static func copies(of entries: [PeekEntry], prefix: String, shiftedBy shift: TimeInterval) -> [PeekEntry] {
        entries.map { $0.copy(id: "\(prefix)-\($0.id.value)", startedAt: $0.startedAt.addingTimeInterval(shift)) }
    }

    /// Ten thousand calls for scrolling and filtering at scale; bodies are shared, not copied.
    static let large: [PeekEntry] = {
        let finished = Fixtures.session.filter { $0.state != .pending }
        return (0..<10_000).map { index in
            let template = finished[index % finished.count]
            return template.copy(id: "l\(index)", startedAt: Fixtures.start.addingTimeInterval(Double(index) * 0.35))
        }
    }()
}

extension PeekEntry {
    func copy(id: String, startedAt newStart: Date) -> PeekEntry {
        let shift = newStart.timeIntervalSince(startedAt)
        return PeekEntry(
            id: PeekId(id),
            request: request,
            startedAt: newStart,
            source: source,
            response: response,
            failure: failure,
            completedAt: completedAt?.addingTimeInterval(shift),
            isPinned: isPinned,
            timings: timings
        )
    }

    func restarted(id: PeekId, at date: Date) -> PeekEntry {
        PeekEntry(id: id, request: request, startedAt: date, source: source)
    }

    func finished(like template: PeekEntry) -> PeekEntry {
        var entry = self
        entry.response = template.response
        entry.failure = template.failure
        entry.timings = template.timings
        entry.completedAt = startedAt.addingTimeInterval(template.duration?.timeInterval ?? 0.3)
        return entry
    }
}
