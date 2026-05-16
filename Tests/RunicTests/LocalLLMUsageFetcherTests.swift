import Foundation
import Testing
@testable import RunicCore

struct LocalLLMUsageFetcherTests {
    @Test
    func `parses ollama model tags`() throws {
        let payload = """
        {
          "models": [
            { "name": "llama3.1:8b" },
            { "model": "qwen2.5-coder:14b" },
            { "name": "llama3.1:8b" }
          ]
        }
        """

        let models = try LocalLLMUsageFetcher.parseOllamaModels(Data(payload.utf8))

        #expect(models == ["llama3.1:8b", "qwen2.5-coder:14b"])
    }

    @Test
    func `parses open AI compatible model list`() throws {
        let payload = """
        {
          "data": [
            { "id": "local/deepseek-r1" },
            { "name": "mlx-community/Qwen3" }
          ]
        }
        """

        let models = try LocalLLMUsageFetcher.parseOpenAIModels(Data(payload.utf8))

        #expect(models == ["local/deepseek-r1", "mlx-community/Qwen3"])
    }
}
