// Adapted from the read-only portions of Stats' SMC reader:
// https://github.com/exelban/stats/blob/master/SMC/smc.swift
//
// Stats is MIT licensed. See THIRD_PARTY_NOTICES.md.
// Tempura intentionally exposes no SMC write API.

import Darwin
import Foundation
import IOKit

public struct RawSMCValue: Sendable {
    public let key: String
    public let dataSize: UInt32
    public let dataType: String
    public let bytes: [UInt8]

    public var doubleValue: Double? {
        guard dataSize > 0, bytes.contains(where: { $0 != 0 }) else {
            return nil
        }

        switch dataType {
        case "ui8 ":
            return byte(at: 0).map(Double.init)
        case "ui16":
            return uint16(at: 0).map(Double.init)
        case "ui32":
            return uint32(at: 0).map(Double.init)
        case "sp1e":
            return fixedPointUnsigned(divisor: 16_384)
        case "sp3c":
            return fixedPointUnsigned(divisor: 4_096)
        case "sp4b":
            return fixedPointUnsigned(divisor: 2_048)
        case "sp5a":
            return fixedPointUnsigned(divisor: 1_024)
        case "sp69":
            return fixedPointUnsigned(divisor: 512)
        case "sp78":
            return fixedPointSigned(divisor: 256)
        case "sp87":
            return fixedPointSigned(divisor: 128)
        case "sp96":
            return fixedPointSigned(divisor: 64)
        case "spa5":
            return fixedPointUnsigned(divisor: 32)
        case "spb4":
            return fixedPointSigned(divisor: 16)
        case "spf0":
            return fixedPointSigned(divisor: 1)
        case "flt ":
            return float32(at: 0).map(Double.init)
        case "fpe2":
            guard bytes.count >= 2 else { return nil }
            return Double((Int(bytes[0]) << 6) + (Int(bytes[1]) >> 2))
        default:
            return nil
        }
    }

    private func byte(at index: Int) -> UInt8? {
        bytes.indices.contains(index) ? bytes[index] : nil
    }

    private func uint16(at index: Int) -> UInt16? {
        guard bytes.count >= index + 2 else { return nil }
        return UInt16(bytes[index]) << 8 | UInt16(bytes[index + 1])
    }

    private func uint32(at index: Int) -> UInt32? {
        guard bytes.count >= index + 4 else { return nil }
        return UInt32(bytes[index]) << 24
            | UInt32(bytes[index + 1]) << 16
            | UInt32(bytes[index + 2]) << 8
            | UInt32(bytes[index + 3])
    }

    private func fixedPointUnsigned(divisor: Double) -> Double? {
        uint16(at: 0).map { Double($0) / divisor }
    }

    private func fixedPointSigned(divisor: Double) -> Double? {
        guard let raw = uint16(at: 0) else { return nil }
        return Double(Int16(bitPattern: raw)) / divisor
    }

    private func float32(at index: Int) -> Float? {
        guard bytes.count >= index + 4 else { return nil }
        var value: Float = 0
        withUnsafeMutableBytes(of: &value) { target in
            target.copyBytes(from: bytes[index..<(index + 4)])
        }
        return value.isFinite ? value : nil
    }
}

public enum SMCClientError: LocalizedError {
    case matchingServiceFailed(kern_return_t)
    case serviceUnavailable
    case openFailed(kern_return_t)

    public var errorDescription: String? {
        switch self {
        case .matchingServiceFailed(let result):
            return "Unable to find AppleSMC service: \(machErrorString(result))"
        case .serviceUnavailable:
            return "AppleSMC service is unavailable on this Mac."
        case .openFailed(let result):
            return "Unable to open AppleSMC service: \(machErrorString(result))"
        }
    }
}

public protocol SMCReadingClient: Sendable {
    func decodedDouble(forKey key: String) -> Double?
    func allKeys() -> [String]
}

public final class SMCClient: SMCReadingClient, @unchecked Sendable {
    private let connection: io_connect_t

    public init() throws {
        guard let matchingDictionary = IOServiceMatching("AppleSMC") else {
            throw SMCClientError.serviceUnavailable
        }

        var iterator: io_iterator_t = 0
        let matchResult = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDictionary, &iterator)
        guard matchResult == kIOReturnSuccess else {
            throw SMCClientError.matchingServiceFailed(matchResult)
        }

        let device = IOIteratorNext(iterator)
        IOObjectRelease(iterator)

        guard device != 0 else {
            throw SMCClientError.serviceUnavailable
        }

        var openedConnection: io_connect_t = 0
        let openResult = IOServiceOpen(device, mach_task_self_, 0, &openedConnection)
        IOObjectRelease(device)

        guard openResult == kIOReturnSuccess else {
            throw SMCClientError.openFailed(openResult)
        }

        connection = openedConnection
    }

    deinit {
        IOServiceClose(connection)
    }

    public func decodedDouble(forKey key: String) -> Double? {
        readValue(forKey: key)?.doubleValue
    }

    public func readValue(forKey key: String) -> RawSMCValue? {
        guard key.utf8.count == 4 else {
            return nil
        }

        var input = SMCKeyData()
        var output = SMCKeyData()

        input.key = smcKeyCode(from: key)
        input.data8 = SMCCommand.readKeyInfo.rawValue

        guard call(SMCCommand.kernelIndex.rawValue, input: &input, output: &output) == kIOReturnSuccess else {
            return nil
        }

        let dataSize = output.keyInfo.dataSize
        let dataType = string(from: output.keyInfo.dataType)

        input.keyInfo.dataSize = dataSize
        input.data8 = SMCCommand.readBytes.rawValue

        guard call(SMCCommand.kernelIndex.rawValue, input: &input, output: &output) == kIOReturnSuccess else {
            return nil
        }

        return RawSMCValue(
            key: key,
            dataSize: UInt32(dataSize),
            dataType: dataType,
            bytes: bytes(from: output.bytes, count: min(Int(dataSize), 32))
        )
    }

    public func allKeys() -> [String] {
        guard let keyCountValue = decodedDouble(forKey: "#KEY"), keyCountValue > 0 else {
            return []
        }

        var keys: [String] = []
        let keyCount = Int(keyCountValue)

        for index in 0..<keyCount {
            var input = SMCKeyData()
            var output = SMCKeyData()
            input.data8 = SMCCommand.readIndex.rawValue
            input.data32 = UInt32(index)

            guard call(SMCCommand.kernelIndex.rawValue, input: &input, output: &output) == kIOReturnSuccess else {
                continue
            }

            let key = string(from: output.key)
            if key.utf8.count == 4 {
                keys.append(key)
            }
        }

        return keys
    }

    private func call(_ index: UInt8, input: inout SMCKeyData, output: inout SMCKeyData) -> kern_return_t {
        let inputSize = MemoryLayout<SMCKeyData>.stride
        var outputSize = MemoryLayout<SMCKeyData>.stride

        return IOConnectCallStructMethod(
            connection,
            UInt32(index),
            &input,
            inputSize,
            &output,
            &outputSize
        )
    }
}

private enum SMCCommand: UInt8 {
    case kernelIndex = 2
    case readBytes = 5
    case readIndex = 8
    case readKeyInfo = 9
}

private typealias SMCBytes = (
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
)

private struct SMCKeyData {
    struct Version {
        var major: CUnsignedChar = 0
        var minor: CUnsignedChar = 0
        var build: CUnsignedChar = 0
        var reserved: CUnsignedChar = 0
        var release: CUnsignedShort = 0
    }

    struct LimitData {
        var version: UInt16 = 0
        var length: UInt16 = 0
        var cpuPLimit: UInt32 = 0
        var gpuPLimit: UInt32 = 0
        var memPLimit: UInt32 = 0
    }

    struct KeyInfo {
        var dataSize: IOByteCount32 = 0
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
    }

    var key: UInt32 = 0
    var version = Version()
    var pLimitData = LimitData()
    var keyInfo = KeyInfo()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: SMCBytes = zeroSMCBytes()
}

private func zeroSMCBytes() -> SMCBytes {
    (
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0
    )
}

private func smcKeyCode(from string: String) -> UInt32 {
    string.utf8.reduce(0) { result, byte in
        result << 8 | UInt32(byte)
    }
}

private func string(from code: UInt32) -> String {
    let bytes = [
        UInt8((code >> 24) & 0xff),
        UInt8((code >> 16) & 0xff),
        UInt8((code >> 8) & 0xff),
        UInt8(code & 0xff)
    ]

    return String(bytes: bytes, encoding: .macOSRoman) ?? ""
}

private func bytes(from tuple: SMCBytes, count: Int) -> [UInt8] {
    var copy = tuple
    return withUnsafeBytes(of: &copy) { rawBuffer in
        Array(rawBuffer.prefix(count))
    }
}

private func machErrorString(_ result: kern_return_t) -> String {
    String(cString: mach_error_string(result))
}
