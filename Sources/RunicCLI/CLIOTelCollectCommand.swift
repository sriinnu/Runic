import Foundation
import Helix
import RunicCore

extension RunicCLI {
    static func runOTelCollect(_ invocation: CommandInvocation) async {
        let port = invocation.parsedValues.options["port"]?.first.flatMap(UInt16.init) ?? 4318
        let host = invocation.parsedValues.options["host"]?.first ?? "127.0.0.1"
        let output = invocation.parsedValues.options["output"]?.first
            .flatMap(Self.expandedFileURL)
            ?? OTelGenAICollectorConfiguration.defaultOutputFile()
        let defaultProvider = invocation.parsedValues.options["defaultProvider"]?.first
            .map(Self.resolveProvider)
        let configuration = OTelGenAICollectorConfiguration(
            host: host,
            port: port,
            outputFile: output,
            defaultProvider: defaultProvider)

        if invocation.parsedValues.flags.contains("once") {
            let input = invocation.parsedValues.options["input"]?.first
            do {
                let data: Data
                if let input, input != "-" {
                    data = try Data(contentsOf: Self.expandedFileURL(input))
                } else {
                    data = FileHandle.standardInput.readDataToEndOfFile()
                }
                let sink = OTelGenAIIngestionSink(configuration: configuration)
                let result = try await sink.ingest(data)
                print("Accepted \(result.acceptedEntries) GenAI usage entr\(result.acceptedEntries == 1 ? "y" : "ies")")
                print("Wrote sanitized ledger: \(result.outputFile.path)")
                return
            } catch {
                Self.exit(code: 1, message: error.localizedDescription)
            }
        }

        #if canImport(Network)
        do {
            let collector = try OTelGenAIHTTPCollector(configuration: configuration)
            collector.start()
            print("Runic OTLP JSON collector listening on http://\(host):\(port)/v1/traces")
            print("Writing sanitized metric JSONL to \(output.path)")
            print("Press Ctrl-C to stop.")
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3600))
            }
            collector.cancel()
        } catch {
            Self.exit(code: 1, message: error.localizedDescription)
        }
        #else
        Self.exit(code: 1, message: "OTLP HTTP collection requires Network.framework on macOS.")
        #endif
    }
}
