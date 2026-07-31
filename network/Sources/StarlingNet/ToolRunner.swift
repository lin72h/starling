// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Exit status + both output streams of a finished child process.
public struct ToolResult {
    public let status: Int32
    public let stdout: String
    public let stderr: String

    public var ok: Bool { status == 0 }

    /// The error a user should see: stderr if the tool wrote one, else a
    /// generic line with the exit status. nmcli writes its failures to stderr
    /// ("Error: Connection activation failed: …"), so surfacing stderr
    /// verbatim is what turns "Connection failed" into an actionable message.
    public var errorText: String {
        let err = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if !err.isEmpty { return err }
        return "exit status \(status)"
    }
}

/// Run an absolute-path tool, capturing stdout and stderr. Blocks the calling
/// thread — callers run this on a background queue, never on main. Both pipes
/// are drained before waitUntilExit so a chatty child can't deadlock against
/// a full pipe (same shape as the App Store's runTool).
public func runTool(_ path: String, _ args: [String]) -> ToolResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: path)
    process.arguments = args
    let outPipe = Pipe(), errPipe = Pipe()
    process.standardOutput = outPipe
    process.standardError = errPipe
    // No stdin: a tool that decides to prompt must fail, not wait forever.
    process.standardInput = FileHandle.nullDevice
    do {
        try process.run()
    } catch {
        return ToolResult(status: -1, stdout: "", stderr: "\(error)")
    }
    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return ToolResult(
        status: process.terminationStatus,
        stdout: String(data: outData, encoding: .utf8) ?? "",
        stderr: String(data: errData, encoding: .utf8) ?? "")
}
