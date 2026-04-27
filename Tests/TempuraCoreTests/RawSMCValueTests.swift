import Testing
@testable import TempuraCore

@Test("Decodes signed 7.8 fixed-point SMC temperature")
func decodesSP78Temperature() {
    let rawValue = RawSMCValue(
        key: "Tp00",
        dataSize: 2,
        dataType: "sp78",
        bytes: [58, 0]
    )

    #expect(rawValue.doubleValue == 58)
}

@Test("Rejects all-zero SMC payloads")
func rejectsZeroPayload() {
    let rawValue = RawSMCValue(
        key: "Tp00",
        dataSize: 2,
        dataType: "sp78",
        bytes: [0, 0]
    )

    #expect(rawValue.doubleValue == nil)
}
