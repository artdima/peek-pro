import AppKit

enum FixtureBodies {
    static let loginRequest = """
    {
      "email": "anna@acme.dev",
      "password": "*****",
      "device": {
        "platform": "ios",
        "model": "iPhone 16 Pro"
      }
    }
    """

    static let loginResponse = """
    {
      "access_token": "*****",
      "refresh_token": "*****",
      "token_type": "Bearer",
      "expires_in": 3600,
      "profile": {
        "id": 1,
        "name": "Anna Petrova",
        "email": "anna@acme.dev",
        "email_verified": true,
        "avatar": null,
        "roles": ["customer", "beta"]
      }
    }
    """

    static let profile = """
    {
      "id": 1,
      "name": "Anna Petrova",
      "email": "anna@acme.dev",
      "phone": null,
      "loyalty": {
        "tier": "gold",
        "points": 12840,
        "expires_at": "2027-03-31T23:59:59Z"
      },
      "addresses": [
        {
          "id": 31,
          "label": "Home",
          "line1": "12 Harbour Street",
          "city": "Lisbon",
          "country": "PT",
          "default": true
        },
        {
          "id": 32,
          "label": "Office",
          "line1": "5 Rua Augusta",
          "city": "Lisbon",
          "country": "PT",
          "default": false
        }
      ],
      "preferences": {
        "newsletter": false,
        "currency": "EUR",
        "size_system": "EU"
      }
    }
    """

    static let userNotFound = """
    {
      "error": "not_found",
      "message": "User 'valdo' does not exist",
      "request_id": "b1f0c2d6-4e8a-4f39-9d3e-2c5b8f1a7e90"
    }
    """

    static let cartItemRequest = """
    {
      "product_id": 1842,
      "size": "42",
      "quantity": 1
    }
    """

    static let cartItemResponse = """
    {
      "id": 42,
      "product_id": 1842,
      "name": "Trail Runner",
      "size": "42",
      "quantity": 1,
      "price": { "amount": 12900, "currency": "EUR" },
      "cart_total": { "amount": 25800, "currency": "EUR" }
    }
    """

    static let serverError = """
    {
      "error": "internal",
      "message": "Unexpected error while resizing the image",
      "trace_id": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
    }
    """

    static let unavailable = """
    {
      "error": "unavailable",
      "message": "Recommendations are temporarily unavailable",
      "retry_after": 30
    }
    """

    static let paymentRequest = """
    {
      "order_id": "ord_8Hq2",
      "amount": { "amount": 25800, "currency": "EUR" },
      "method": "card",
      "card_token": "*****",
      "save_card": true
    }
    """

    static let paymentErrors = """
    {
      "error": "validation_failed",
      "fields": [
        { "field": "card_token", "code": "expired", "message": "The card has expired" },
        { "field": "amount", "code": "limit", "message": "Amount exceeds the daily limit" }
      ]
    }
    """

    static let documentCreated = """
    {
      "id": "doc_91Kx",
      "filename": "receipt-2026-09.pdf",
      "size": 482113,
      "folder": "expenses",
      "created_at": "2026-09-23T14:55:12Z"
    }
    """

    static let tokenRequest = "grant_type=refresh_token&refresh_token=*****&client_id=acme-shop-ios&scope=profile%20orders"

    static let tokenResponse = """
    {
      "access_token": "*****",
      "token_type": "Bearer",
      "expires_in": 3600,
      "scope": "profile orders"
    }
    """

    static let graphqlRequest = """
    {
      "operationName": "ProductPage",
      "query": "query ProductPage($id: ID!) { product(id: $id) { id name price { amount currency } stock reviews(first: 3) { rating text } } }",
      "variables": { "id": "1842" }
    }
    """

    static let graphqlResponse = """
    {
      "data": {
        "product": {
          "id": "1842",
          "name": "Trail Runner",
          "price": { "amount": 12900, "currency": "EUR" },
          "stock": 14,
          "reviews": null
        }
      },
      "errors": [
        {
          "message": "Reviews service timed out",
          "path": ["product", "reviews"],
          "extensions": { "code": "UPSTREAM_TIMEOUT" }
        }
      ]
    }
    """

    static let product = """
    {
      "id": 1842,
      "name": "Trail Runner",
      "brand": "Acme",
      "price": { "amount": 12900, "currency": "EUR" },
      "sizes": ["39", "40", "41", "42", "43", "44"],
      "colors": ["olive", "black"],
      "rating": 4.6,
      "reviews_count": 318,
      "description": "A lightweight trail shoe with a grippy outsole and a breathable mesh upper."
    }
    """

    static let reviews = """
    {
      "page": 2,
      "items": [
        { "id": 9012, "rating": 5, "author": "Marta", "text": "Great grip on wet rocks." },
        { "id": 9013, "rating": 4, "author": "Joao", "text": "Runs half a size small." },
        { "id": 9014, "rating": 3, "author": "Li", "text": "Comfortable, but the laces keep untying." }
      ],
      "next": "/v1/products/1842/reviews?page=3"
    }
    """

    static let featureFlags = """
    {
      "checkout_v2": true,
      "apple_pay": true,
      "reviews_ai_summary": false,
      "min_supported_version": "3.2.0",
      "experiments": {
        "search_ranking": "control",
        "home_layout": "grid"
      }
    }
    """

    static let settingsRequest = """
    {
      "newsletter": true,
      "currency": "EUR",
      "size_system": "EU"
    }
    """

    static let rateLimited = """
    {
      "error": "rate_limited",
      "message": "Too many requests, slow down",
      "retry_after": 12
    }
    """

    static let unauthorized = """
    {
      "error": "invalid_token",
      "message": "The access token expired"
    }
    """

    static let forbidden = """
    {
      "error": "forbidden",
      "message": "Admin role required"
    }
    """

    static let promoPage = """
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <title>Autumn Sale — Acme</title>
    </head>
    <body>
      <h1>Autumn Sale</h1>
      <p>Up to 40% off trail and running shoes until October 5.</p>
      <a href="/catalog?collection=autumn">Shop now</a>
    </body>
    </html>
    """

    static let faqPage = """
    <!doctype html>
    <html lang="en">
    <head><meta charset="utf-8"><title>Help — Acme</title></head>
    <body>
      <h1>Frequently asked questions</h1>
      <h2>How do I return an order?</h2>
      <p>Open the order, tap Return and pick a drop-off point. Returns are free within 30 days.</p>
      <h2>When will I get my refund?</h2>
      <p>Within 5 business days after the parcel reaches our warehouse.</p>
    </body>
    </html>
    """

    static let sitemap = """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
      <url><loc>https://www.acme.dev/</loc><changefreq>daily</changefreq></url>
      <url><loc>https://www.acme.dev/catalog</loc><changefreq>hourly</changefreq></url>
      <url><loc>https://www.acme.dev/promo</loc><changefreq>weekly</changefreq></url>
    </urlset>
    """

    /// About a megabyte and 26 000 lines: large enough to show whether the body viewer keeps up.
    static let catalog: String = {
        let adjectives = ["Classic", "Urban", "Trail", "Court", "Retro", "Aero", "Studio", "Coastal"]
        let nouns = ["Sneaker", "Runner", "Boot", "Loafer", "Slide", "Trainer", "High-Top", "Mule"]
        let colors = ["black", "white", "sand", "olive", "navy", "crimson"]
        let count = 2_400
        var lines = ["{", "  \"page\": 1,", "  \"per_page\": \(count),", "  \"total\": 48213,", "  \"items\": ["]
        lines.reserveCapacity(count * 11 + 8)
        for index in 0..<count {
            let id = 100_000 + index * 7
            let color = colors[index % colors.count]
            let name = "\(adjectives[index % adjectives.count]) \(nouns[(index / 8) % nouns.count])"
            let price = Double(4_900 + (index * 137) % 20_000) / 100
            lines.append("    {")
            lines.append("      \"id\": \(id),")
            lines.append("      \"sku\": \"AC-\(id)-\(color.uppercased())\",")
            lines.append("      \"name\": \"\(name)\",")
            lines.append("      \"price\": \(String(format: "%.2f", price)),")
            lines.append("      \"currency\": \"EUR\",")
            lines.append("      \"in_stock\": \(index % 5 != 0),")
            lines.append("      \"rating\": \(Double(30 + index % 21) / 10),")
            lines.append("      \"tags\": [\"\(color)\", \"new\"],")
            lines.append("      \"image\": \"https://cdn.acme.dev/products/\(id).jpg\"")
            lines.append(index == count - 1 ? "    }" : "    },")
        }
        lines += ["  ],", "  \"next\": \"/v1/catalog?page=2&per_page=\(count)\"", "}"]
        return lines.joined(separator: "\n")
    }()

    /// A prefix cut mid-document, the way the device keeps an over-limit body.
    static let truncatedFeed: String = {
        var lines = ["{", "  \"items\": ["]
        for index in 0..<600 {
            lines.append("    { \"id\": \(9_000 + index), \"type\": \"post\", \"title\": \"Story number \(index)\", \"likes\": \(index * 13 % 997) },")
        }
        lines.append("    { \"id\": 9600, \"type\": \"post\", \"title\": \"Story num")
        return lines.joined(separator: "\n")
    }()

    static let protobuf: Data = Data((0..<2_048).map { UInt8(truncatingIfNeeded: ($0 &* 37) ^ ($0 >> 3)) })

    static let avatarPNG: Data = {
        let side = 96
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: side,
            pixelsHigh: side,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return Data() }
        let bounds = NSRect(x: 0, y: 0, width: side, height: side)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSGradient(colors: [.systemTeal, .systemIndigo])?.draw(in: bounds, angle: 45)
        NSColor.white.withAlphaComponent(0.9).setFill()
        NSBezierPath(ovalIn: bounds.insetBy(dx: 30, dy: 30)).fill()
        NSGraphicsContext.restoreGraphicsState()
        return bitmap.representation(using: .png, properties: [:]) ?? Data()
    }()

    static let timeoutStackTrace = """
    #0      DioMixin.fetch.<anonymous closure> (package:dio/src/dio_mixin.dart:522:7)
    #1      _RootZone.runBinary (dart:async/zone.dart:1666:54)
    #2      _FutureListener.handleError (dart:async/future_impl.dart:177:22)
    #3      Future._propagateToListeners.handleError (dart:async/future_impl.dart:852:47)
    #4      Future._propagateToListeners (dart:async/future_impl.dart:873:13)
    #5      Future._completeError (dart:async/future_impl.dart:652:5)
    #6      OrdersRepository.fetchOpen (package:acme_shop/data/orders_repository.dart:41:24)
    <asynchronous suspension>
    #7      OrdersCubit.load (package:acme_shop/features/orders/orders_cubit.dart:28:19)
    <asynchronous suspension>
    """

    static let connectionStackTrace = """
    #0      _NativeSocket.startConnect (dart:io-patch/socket_patch.dart:733:35)
    #1      _RawSocket.startConnect (dart:io-patch/socket_patch.dart:1895:26)
    #2      RawSocket.startConnect (dart:io-patch/socket_patch.dart:27:23)
    #3      Socket._startConnect (dart:io-patch/socket_patch.dart:2127:22)
    #4      _HttpClient._openUrl (dart:_http/http_impl.dart:2913:10)
    #5      AnalyticsUploader.flush (package:acme_shop/analytics/uploader.dart:64:18)
    <asynchronous suspension>
    """
}
