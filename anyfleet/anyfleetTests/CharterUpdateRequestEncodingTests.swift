import Foundation
import Testing
@testable import anyfleet

@Suite("CharterUpdateRequest encoding")
struct CharterUpdateRequestEncodingTests {

    @Test("Encodes explicit JSON null for on_behalf when clearing virtual captain attribution")
    func testEncodeOnBehalfNull() throws {
        let req = CharterUpdateRequest(
            name: "Trip",
            boatName: nil,
            locationText: nil,
            startDate: nil,
            endDate: nil,
            visibility: "public",
            latitude: nil,
            longitude: nil,
            locationPlaceId: nil,
            onBehalfOfVirtualCaptainId: nil,
            shouldEncodeOnBehalfOfVirtualCaptainId: true
        )
        let data = try JSONEncoder().encode(req)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(obj?["on_behalf_of_virtual_captain_id"] is NSNull)
        #expect(obj?["name"] as? String == "Trip")
    }

    @Test("Omits on_behalf key when shouldEncodeOnBehalf is false")
    func testOmitOnBehalf() throws {
        let req = CharterUpdateRequest(
            name: nil,
            boatName: nil,
            locationText: nil,
            startDate: nil,
            endDate: nil,
            visibility: nil,
            latitude: nil,
            longitude: nil,
            locationPlaceId: nil,
            onBehalfOfVirtualCaptainId: UUID(),
            shouldEncodeOnBehalfOfVirtualCaptainId: false
        )
        let data = try JSONEncoder().encode(req)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(obj?["on_behalf_of_virtual_captain_id"] == nil)
    }
}
