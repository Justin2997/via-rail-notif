import Foundation
import Testing
@testable import RailCore

struct LocalizationTests {
    private func bundle(_ language: String) throws -> Bundle {
        let url = try #require(RailLocalization.bundle.url(forResource: language, withExtension: "lproj"))
        return try #require(Bundle(url: url))
    }

    @Test func alarmErrorsSupportEnglishAndFrench() throws {
        let key: String.LocalizationValue = "Autorisez les alarmes dans les réglages de l’iPhone."
        #expect(String(localized: key, bundle: try bundle("en")) ==
                "Allow alarms in your iPhone’s settings.")
        #expect(String(localized: key, bundle: try bundle("fr")) ==
                "Autorisez les alarmes dans les réglages de l’iPhone.")
    }

    @Test func localizedErrorPreservesDetails() throws {
        let detail = "CSV header"
        #expect(String(localized: "Données VIA invalides : \(detail).", bundle: try bundle("en")) == "Invalid VIA data: CSV header.")
        #expect(String(localized: "Données VIA invalides : \(detail).", bundle: try bundle("fr")) == "Données VIA invalides : CSV header.")
    }
}
