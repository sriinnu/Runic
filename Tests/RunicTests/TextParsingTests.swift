import RunicCore
import Testing

struct TextParsingTests {
    @Test
    func `strip ANSI codes removes cursor visibility CSI`() {
        let input = "\u{001B}[?25hhello\u{001B}[0m"
        let stripped = TextParsing.stripANSICodes(input)
        #expect(stripped == "hello")
    }

    /// Claude Code 2.1 positions words with cursor moves instead of spaces.
    @Test
    func `strip ANSI codes renders cursor column and forward moves as spaces`() {
        let column = "\u{001B}[3G\u{001B}[1mCurrent\u{001B}[11Gsession\u{001B}[22m\r\n\u{001B}[3G9%\u{001B}[2Cused"
        #expect(TextParsing.stripANSICodes(column) == "  Current session\r\n  9%  used")
        // A move back to a column already passed adds nothing.
        #expect(TextParsing.stripANSICodes("abcdef\u{001B}[2Gx") == "abcdefx")
    }
}
