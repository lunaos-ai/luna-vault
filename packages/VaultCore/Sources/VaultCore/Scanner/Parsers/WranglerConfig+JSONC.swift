import Foundation

extension WranglerConfig {
    static func stripJSONCComments(_ content: String) -> String {
        var output = ""
        var index = content.startIndex
        var inString = false
        var escaped = false
        while index < content.endIndex {
            let ch = content[index]
            let next = content.index(after: index)
            if inString {
                output.append(ch)
                if escaped {
                    escaped = false
                } else if ch == "\\" {
                    escaped = true
                } else if ch == "\"" {
                    inString = false
                }
                index = next
                continue
            }
            if ch == "\"" {
                inString = true
                output.append(ch)
                index = next
                continue
            }
            if ch == "/", next < content.endIndex {
                let peek = content[next]
                if peek == "/" {
                    index = content.index(after: next)
                    while index < content.endIndex, content[index] != "\n" {
                        index = content.index(after: index)
                    }
                    if index < content.endIndex { output.append("\n") }
                    continue
                }
                if peek == "*" {
                    index = content.index(after: next)
                    while index < content.endIndex {
                        let current = content[index]
                        let afterCurrent = content.index(after: index)
                        if current == "*", afterCurrent < content.endIndex, content[afterCurrent] == "/" {
                            index = content.index(after: afterCurrent)
                            break
                        }
                        if current == "\n" { output.append("\n") }
                        index = afterCurrent
                    }
                    continue
                }
            }
            output.append(ch)
            index = next
        }
        return output
    }

    static func stripTrailingCommas(_ content: String) -> String {
        var output = ""
        var index = content.startIndex
        var inString = false
        var escaped = false
        while index < content.endIndex {
            let ch = content[index]
            let next = content.index(after: index)
            if inString {
                output.append(ch)
                if escaped {
                    escaped = false
                } else if ch == "\\" {
                    escaped = true
                } else if ch == "\"" {
                    inString = false
                }
                index = next
                continue
            }
            if ch == "\"" {
                inString = true
                output.append(ch)
                index = next
                continue
            }
            if ch == "," {
                var lookahead = next
                while lookahead < content.endIndex, content[lookahead].isWhitespace {
                    lookahead = content.index(after: lookahead)
                }
                if lookahead < content.endIndex, content[lookahead] == "}" || content[lookahead] == "]" {
                    index = next
                    continue
                }
            }
            output.append(ch)
            index = next
        }
        return output
    }
}
