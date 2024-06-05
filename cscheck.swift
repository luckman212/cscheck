#!/usr/bin/swift

// https://chatgpt.com/c/598143ad-22ca-445b-bcd4-ddc412a044b8

import Foundation
import Security

class StandardError: TextOutputStream {
    func write(_ string: String) {
        try! FileHandle.standardError.write(contentsOf: Data(string.utf8))
    }
}

var stdErr = StandardError()

func getCodeSigningInfo(for appPath: String) -> [String: AnyObject]? {
    var staticCode: SecStaticCode?
    let status = SecStaticCodeCreateWithPath(URL(fileURLWithPath: appPath) as CFURL, [], &staticCode)

    guard status == errSecSuccess, let code = staticCode else {
        print("error checking \(appPath) [\(status)]", to: &stdErr)
        return nil
    }

    var codeInfo: CFDictionary?
    let infoStatus = SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &codeInfo)

    guard infoStatus == errSecSuccess, let info = codeInfo as? [String: AnyObject] else {
        print("Failed to get signing information for \(appPath). Status: \(infoStatus)", to: &stdErr)
        return nil
    }

    return info
}

func printDeveloperCertificateInfo(for appPath: String, certificates: [SecCertificate], teamIdentifier: String?) {
    if certificates.isEmpty {
        print("No certificates found for \(appPath)", to: &stdErr)
        return
    }

    print("App: \(appPath)")

    // Extract SHA-256 Fingerprint
    for certificate in certificates {
        let values = SecCertificateCopyValues(certificate, nil, nil) as? [CFString: AnyObject]

        if let fingerprintsDict = values?["Fingerprints" as CFString] as? [CFString: AnyObject],
           let fingerprints = fingerprintsDict[kSecPropertyKeyValue] as? [[CFString: AnyObject]] {
            for fingerprint in fingerprints {
                if let label = fingerprint[kSecPropertyKeyLabel] as? String, label == "SHA-256",
                   let fingerprintData = fingerprint[kSecPropertyKeyValue] as? Data {
                    let fingerprintString = fingerprintData.map { String(format: "%02hhx", $0) }.joined()
                    print("SHA-256 Fingerprint: \(fingerprintString)")
                }
            }
        } else {
            print("Failed to get SHA-256 fingerprint for \(appPath)", to: &stdErr)
        }

        // Extract Developer ID and Name
        var developerID: String? = teamIdentifier
        var developerName: String?

        if let subjectNameDict = values?["2.16.840.1.113741.2.1.1.1.8" as CFString] as? [CFString: AnyObject],
           let subjectNameValue = subjectNameDict[kSecPropertyKeyValue] as? [[CFString: AnyObject]] {
            for attribute in subjectNameValue {
                if let label = attribute[kSecPropertyKeyLabel] as? String,
                   let value = attribute[kSecPropertyKeyValue] as? String {
                    if label == "0.9.2342.19200300.100.1.1" || label == "2.5.4.5" {
                        developerID = value
                    } else if label == "2.5.4.3" {
                        developerName = value
                    }
                }
            }
        }

        if developerID == nil {
            if let idValue = values?["2.5.4.5" as CFString] as? [CFString: AnyObject],
               let id = idValue[kSecPropertyKeyValue] as? String {
                developerID = id
            }
        }
        if developerName == nil {
            if let nameValue = values?["2.5.4.3" as CFString] as? [CFString: AnyObject],
               let name = nameValue[kSecPropertyKeyValue] as? String {
                developerName = name
            }
        }

        if let id = developerID {
            print("Developer ID: \(id)")
        } else {
            print("Failed to get Developer ID for \(appPath)", to: &stdErr)
        }

        if let name = developerName {
            if let range = name.range(of: "Developer ID Application: ") {
                print("Developer Name: \(name[range.upperBound...])")
            } else {
                print("Developer Name: \(name)")
            }
        } else {
            print("Failed to get Developer Name for \(appPath)", to: &stdErr)
        }

        // If we found the information, no need to continue checking further certificates
        if developerID != nil && developerName != nil {
            break
        }
    }
}

func main() {
    guard CommandLine.arguments.count > 1 else {
        print("Usage: cscheck <path> [<path>...]")
        exit(0)
    }

    let appPaths = CommandLine.arguments.dropFirst()

    for appPath in appPaths {
        guard let codeSigningInfo = getCodeSigningInfo(for: appPath) else {
            continue
        }

        // Extract team identifier if present
        let teamIdentifier = codeSigningInfo[kSecCodeInfoTeamIdentifier as String] as? String

        if let certificates = codeSigningInfo[kSecCodeInfoCertificates as String] as? [SecCertificate] {
            printDeveloperCertificateInfo(for: appPath, certificates: certificates, teamIdentifier: teamIdentifier)
        } else {
            print("No certificates found in signing information for \(appPath)", to: &stdErr)
            if CommandLine.arguments.count == 2 {
                exit(1)
            }
        }
    }
}

main()
