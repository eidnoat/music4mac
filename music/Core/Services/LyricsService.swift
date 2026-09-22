import Foundation

public final class LyricsService {
    public static let shared = LyricsService()
    
    // Precompiled regex patterns
    private static let offsetRegex: NSRegularExpression? = {
        let pattern = #"^\[offset:\s*([+-]?\d+)\s*\]"#
        return try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
    }()
    
    private static let tagRegex: NSRegularExpression? = {
        let pattern = #"[\[<]\s*(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\s*[\]>]"#
        return try? NSRegularExpression(pattern: pattern)
    }()
    
    private init() {}
    
    /// Parses LRC content into a ParsedLyrics structure supporting standard LRC, multi-timestamp lines, and word-level Karaoke
    public func parse(lrcContent: String, songDuration: TimeInterval? = nil) -> ParsedLyrics {
        var result = ParsedLyrics()
        let rawLines = lrcContent
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        if rawLines.isEmpty {
            result.lines.append(LyricLine(start: 0, text: "No lyrics available"))
            return result
        }
        
        var parsedOffset: TimeInterval = 0
        var rawParsedLines: [(starts: [TimeInterval], text: String, tokens: [LyricToken])] = []
        
        for line in rawLines {
            let nsLine = line as NSString
            let lineRange = NSRange(location: 0, length: nsLine.length)
            
            // Check for [offset: +/- ms]
            if let offsetRegex = Self.offsetRegex,
               let match = offsetRegex.firstMatch(in: line, range: lineRange) {
                let valRange = match.range(at: 1)
                if valRange.location != NSNotFound,
                   let ms = Int(nsLine.substring(with: valRange)) {
                    parsedOffset = Double(ms) / 1000.0
                }
                continue
            }
            
            guard let tagRegex = Self.tagRegex else { continue }
            let allTagMatches = tagRegex.matches(in: line, range: lineRange)
            guard !allTagMatches.isEmpty else { continue }
            
            // Check consecutive leading tags, e.g. [00:12.30][01:15.20]
            var leadingTags: [NSTextCheckingResult] = []
            var nextExpectedLocation = 0
            for match in allTagMatches {
                if match.range.location == nextExpectedLocation {
                    leadingTags.append(match)
                    nextExpectedLocation = match.range.location + match.range.length
                } else {
                    break
                }
            }
            
            // Must start with at least one timestamp tag at location 0
            guard !leadingTags.isEmpty else { continue }
            
            let remainingTags = allTagMatches.dropFirst(leadingTags.count)
            
            if remainingTags.isEmpty {
                // Standard line: text after leading tags
                let text = nsLine.substring(from: nextExpectedLocation).trimmingCharacters(in: .whitespaces)
                if !text.isEmpty {
                    let starts = leadingTags.map { parseTimestamp(match: $0, in: nsLine) }
                    rawParsedLines.append((starts: starts, text: text, tokens: []))
                }
            } else {
                // Inline tokenized Karaoke line: e.g. [00:02.00]Hello [00:02.50]beautiful [00:03.00]world
                var tokens: [LyricToken] = []
                let karaokeTags = Array(allTagMatches)
                for i in 0..<karaokeTags.count {
                    let currentTag = karaokeTags[i]
                    let tokenStart = parseTimestamp(match: currentTag, in: nsLine)
                    let nextTextStart = currentTag.range.location + currentTag.range.length
                    let nextTextEnd = (i + 1 < karaokeTags.count) ? karaokeTags[i + 1].range.location : nsLine.length
                    
                    if nextTextEnd > nextTextStart {
                        let textRange = NSRange(location: nextTextStart, length: nextTextEnd - nextTextStart)
                        let tokenText = nsLine.substring(with: textRange)
                        let nextTokenStart = (i + 1 < karaokeTags.count) ? parseTimestamp(match: karaokeTags[i + 1], in: nsLine) : nil
                        
                        if !tokenText.isEmpty {
                            tokens.append(LyricToken(start: tokenStart, text: tokenText, end: nextTokenStart))
                        }
                    }
                }
                
                if !tokens.isEmpty {
                    result.isKaraoke = true
                    let lineStart = parseTimestamp(match: leadingTags[0], in: nsLine)
                    let fullText = tokens.map { $0.text }.joined().trimmingCharacters(in: .whitespaces)
                    rawParsedLines.append((starts: [lineStart], text: fullText, tokens: tokens))
                }
            }
        }
        
        result.offset = parsedOffset
        
        // Expand lines with multiple timestamps and flatten
        var allLines: [LyricLine] = []
        for item in rawParsedLines {
            if item.text.isEmpty && item.tokens.isEmpty {
                continue
            }
            for start in item.starts {
                let adjustedStart = max(0, start - parsedOffset)
                var adjustedTokens = item.tokens
                if parsedOffset != 0 && !adjustedTokens.isEmpty {
                    for idx in adjustedTokens.indices {
                        adjustedTokens[idx] = LyricToken(
                            start: max(0, adjustedTokens[idx].start - parsedOffset),
                            text: adjustedTokens[idx].text,
                            end: adjustedTokens[idx].end.map { max(0, $0 - parsedOffset) }
                        )
                    }
                }
                
                allLines.append(LyricLine(
                    start: adjustedStart,
                    text: item.text,
                    tokens: adjustedTokens
                ))
            }
        }
        
        // Sort lines chronologically
        allLines.sort { $0.start < $1.start }
        
        // Merge identical or near-identical timestamps as translations
        var mergedLines: [LyricLine] = []
        for line in allLines {
            if let lastIdx = mergedLines.indices.last,
               abs(mergedLines[lastIdx].start - line.start) < 0.05 {
                mergedLines[lastIdx].translates.append(line.text)
            } else {
                mergedLines.append(line)
            }
        }
        
        // Calculate sensible `end` timestamps for each line
        for i in 0..<mergedLines.count {
            if i + 1 < mergedLines.count {
                let nextStart = mergedLines[i + 1].start
                let gap = nextStart - mergedLines[i].start
                // If gap is large (> 9s, instrumental solo), don't keep line active indefinitely
                if gap > 9.0 {
                    let charCount = mergedLines[i].text.count
                    let estimatedDuration = min(max(Double(charCount) * 0.35, 3.5), gap - 1.0)
                    mergedLines[i].end = mergedLines[i].start + estimatedDuration
                } else {
                    mergedLines[i].end = nextStart
                }
            } else {
                if let dur = songDuration, dur > mergedLines[i].start {
                    mergedLines[i].end = dur
                } else {
                    mergedLines[i].end = mergedLines[i].start + 5.0
                }
            }
            
            // Also ensure last token of karaoke line has an end
            if !mergedLines[i].tokens.isEmpty, let lastTokIdx = mergedLines[i].tokens.indices.last {
                if mergedLines[i].tokens[lastTokIdx].end == nil {
                    mergedLines[i].tokens[lastTokIdx].end = mergedLines[i].end
                }
            }
        }
        
        if mergedLines.isEmpty {
            mergedLines.append(LyricLine(start: 0, text: "No lyrics available"))
        }
        
        result.lines = mergedLines
        return result
    }
    
    private func parseTimestamp(match: NSTextCheckingResult, in string: NSString) -> TimeInterval {
        let minRange = match.range(at: 1)
        let secRange = match.range(at: 2)
        
        let minutes = Double(string.substring(with: minRange)) ?? 0
        let seconds = Double(string.substring(with: secRange)) ?? 0
        var fraction = 0.0
        
        if match.numberOfRanges > 3 {
            let msRange = match.range(at: 3)
            if msRange.location != NSNotFound {
                let msStr = string.substring(with: msRange)
                if msStr.count == 1 {
                    fraction = (Double(msStr) ?? 0) / 10.0
                } else if msStr.count == 2 {
                    fraction = (Double(msStr) ?? 0) / 100.0
                } else {
                    let prefix = String(msStr.prefix(3))
                    fraction = (Double(prefix) ?? 0) / 1000.0
                }
            }
        }
        
        return (minutes * 60.0) + seconds + fraction
    }
    
    /// Finds the currently active lyric line index for given playback position.
    /// Includes a subtle 0.15s lead time for natural reading anticipation and smooth scroll synchronization.
    public func activeLineIndex(in lines: [LyricLine], position: TimeInterval, offset: TimeInterval = 0) -> Int {
        let adjustedPos = position + offset + 0.15
        if adjustedPos < 0 || lines.isEmpty { return -1 }
        
        // Before the first line begins
        if adjustedPos < lines[0].start {
            return -1
        }
        
        var activeIndex = -1
        for (i, line) in lines.enumerated() {
            if adjustedPos >= line.start {
                activeIndex = i
            } else {
                break
            }
        }
        return activeIndex
    }
}
