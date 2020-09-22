/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Utilities for dealing with recognized strings
*/

import Foundation

extension Character {
	func getSimilarCharacterIfNotIn(allowedChars: String) -> Character {
		let conversionTable = [
			"s": "S",
			"S": "5",
			"5": "S",
			"o": "O",
			"Q": "O",
			"O": "0",
			"0": "O",
			"l": "I",
			"I": "1",
			"1": "I",
			"B": "8",
			"8": "B"
		]
		// Allow a maximum of two substitutions to handle 's' -> 'S' -> '5'.
		let maxSubstitutions = 2
		var current = String(self)
		var counter = 0
		while !allowedChars.contains(current) && counter < maxSubstitutions {
			if let altChar = conversionTable[current] {
				current = altChar
				counter += 1
			} else {
				// Doesn't match anything in our table. Give up.
				break
			}
		}
		
		return current.first!
	}
}

extension String {
        
    struct ExtractedInvoiceValue: Hashable {
        let range: Range<String.Index>
        let value: String
        let type: CaptureType
    }
    
    func extractInvoiceValue() -> ExtractedInvoiceValue? {
        if let extractedBankGiro = extractBankGiroNumber() {
            return .init(range: extractedBankGiro.0, value: extractedBankGiro.1, type: .accountNumber)
        }
        
        if let extractedReference = extractSwedishInvoiceNumber() {
            return .init(range: extractedReference.0, value: extractedReference.1, type: .reference)
        }
        
        if let extranctedAmount = extractAmount() {
            return .init(range: extranctedAmount.0, value: extranctedAmount.1, type: .amount)
        }
        
        return nil
    }
    
    func extractBankGiroNumber() -> (Range<String.Index>, String)? {
        var result = ""
        let allowedChars = "0123456789#"
        let pattern = "[1-9]\\d{6,7}#\\d{2}#"
        
        guard let range = self.range(of: pattern, options: .regularExpression, range: nil, locale: nil) else {
            return nil
        }

        let digits = String(self[range])

        for var char in digits {
            char = char.getSimilarCharacterIfNotIn(allowedChars: allowedChars)
            guard allowedChars.contains(char) else {
                return nil
            }
            result.append(char)
        }
        return (range, result)
    }
    
    func extractSwedishInvoiceNumber() -> (Range<String.Index>, String)? {
        var result = ""
        let allowedChars = "0123456789# "
        let pattern = "\\d{3,20}\\s#"
        
        guard let range = self.range(of: pattern, options: .regularExpression, range: nil, locale: nil) else {
            return nil
        }

        let digits = String(self[range])
        
        guard digits.count > 5, digits.count < 25 else {
            return nil
        }

        for var char in digits {
            char = char.getSimilarCharacterIfNotIn(allowedChars: allowedChars)
            guard allowedChars.contains(char) else {
                return nil
            }
            result.append(char)
        }
        return (range, result)
    }
    
    func extractAmount() -> (Range<String.Index>, String)? {
        var result = ""
        let allowedChars = "0123456789 "
        let pattern = "\\d{1,7}\\s[05]0"

        guard let range = self.range(of: pattern, options: .regularExpression, range: nil, locale: nil) else {
            return nil
        }

        let digits = String(self[range])
        


        for var char in digits {
            char = char.getSimilarCharacterIfNotIn(allowedChars: allowedChars)
            guard allowedChars.contains(char) else {
                return nil
            }
            result.append(char)
        }
        return (range, result)
    }
}

class CameraScannerStringTracker {
	var frameIndex: Int64 = 0

	typealias StringObservation = (lastSeen: Int64, count: Int64)
	
	// Dictionary of seen strings. Used to get stable recognition before
	// displaying anything.
    var seenStrings = [String.ExtractedInvoiceValue: StringObservation]()
	var bestCount = Int64(0)
    var bestString: String.ExtractedInvoiceValue?

	func logFrame(strings: [String.ExtractedInvoiceValue]) {
		for string in strings {
			if seenStrings[string] == nil {
				seenStrings[string] = (lastSeen: Int64(0), count: Int64(-1))
			}
			seenStrings[string]?.lastSeen = frameIndex
			seenStrings[string]?.count += 1
			print("Seen \(string) \(seenStrings[string]?.count ?? 0) times")
		}
	
		var obsoleteStrings = [String.ExtractedInvoiceValue]()

		// Go through strings and prune any that have not been seen in while.
		// Also find the (non-pruned) string with the greatest count.
		for (string, obs) in seenStrings {
			// Remove previously seen text after 30 frames (~1s).
			if obs.lastSeen < frameIndex - 30 {
				obsoleteStrings.append(string)
			}
			
			// Find the string with the greatest count.
			let count = obs.count
			if !obsoleteStrings.contains(string) && count > bestCount {
				bestCount = Int64(count)
				bestString = string
			}
		}
		// Remove old strings.
		for string in obsoleteStrings {
			seenStrings.removeValue(forKey: string)
		}
		
		frameIndex += 1
	}
	
	func getStableString() -> String.ExtractedInvoiceValue? {
		// Require the recognizer to see the same string at least 10 times.
		if bestCount >= 10 {
			return bestString
		} else {
			return nil
		}
	}
	
	func reset(string: String.ExtractedInvoiceValue) {
		seenStrings.removeValue(forKey: string)
		bestCount = 0
		bestString = nil
	}
}
