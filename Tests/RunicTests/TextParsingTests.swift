import RunicCore
import Testing

struct TextParsingTests {
    @Test
    func `strip ANSI codes removes cursor visibility CSI`() {
        let input = "\u{001B}[?25hhello\u{001B}[0m"
        let stripped = TextParsing.stripANSICodes(input)
        #expect(stripped == "hello")
    }
}
