// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

// MARK: - Models

/// One audio output as wpctl lists it.
public struct AudioSink: Equatable {
    public let id: Int
    public let name: String
    public let isDefault: Bool

    public init(id: Int, name: String, isDefault: Bool) {
        self.id = id
        self.name = name
        self.isDefault = isDefault
    }
}

/// Point-in-time picture of the default output and the sinks to pick from.
public struct AudioStatus: Equatable {
    /// PipeWire answered. False means no daemon (or no wpctl): the Sound
    /// pane says so instead of drawing a slider that moves nothing.
    public var available = false
    /// Default sink volume, 0.0–1.0 (wpctl can report >1 for boosted
    /// outputs; callers clamp for display, not here — the boost is real).
    public var volume: Double = 0
    public var muted = false
    /// Real output devices only. PipeWire filters (echo-cancel loopbacks,
    /// virtual mics) also carry Audio/Sink media classes, but showing a
    /// user "vmic_sink" as a speaker is a lie — a machine with no sound
    /// hardware shows an empty list and says so.
    public var sinks: [AudioSink] = []

    public init() {}
}

// MARK: - Control

/// Talks to PipeWire through `wpctl` — the same tool a user would type, so
/// anything this reports can be checked by hand. Synchronous process runs;
/// call off the main thread.
public enum AudioControl {

    /// The Starling session points XDG_RUNTIME_DIR at its own private dir
    /// (/tmp/xdg-starling-<uid>), but PipeWire's socket lives in the real
    /// logind one — libpipewire resolves it through XDG_RUNTIME_DIR unless
    /// PIPEWIRE_RUNTIME_DIR overrides. Without the override every wpctl
    /// call inside the session fails with "Host is down" while the exact
    /// same command works over SSH, which reads as a PipeWire bug and is
    /// just an environment one. (app-run.sh solves the same problem for
    /// third-party apps with the pulse socket.)
    static func environment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        if env["PIPEWIRE_RUNTIME_DIR"] == nil {
            let real = "/run/user/\(getuid())"
            if FileManager.default.fileExists(atPath: real + "/pipewire-0") {
                env["PIPEWIRE_RUNTIME_DIR"] = real
            }
        }
        return env
    }

    public static func status() -> AudioStatus {
        var status = AudioStatus()
        let vol = run(["get-volume", "@DEFAULT_AUDIO_SINK@"])
        guard vol.ok, let parsed = parseVolume(vol.stdout) else { return status }
        status.available = true
        status.volume = parsed.volume
        status.muted = parsed.muted
        let tree = run(["status"])
        if tree.ok { status.sinks = parseSinks(fromStatus: tree.stdout) }
        return status
    }

    /// Set the default sink's volume, clamped to 0–1: the slider must not
    /// be able to push into the >100% boost range a stray drag would reach.
    @discardableResult
    public static func setVolume(_ volume: Double) -> Bool {
        let v = min(max(volume, 0), 1)
        return run(["set-volume", "@DEFAULT_AUDIO_SINK@",
                    String(format: "%.2f", v)]).ok
    }

    @discardableResult
    public static func setMuted(_ muted: Bool) -> Bool {
        run(["set-mute", "@DEFAULT_AUDIO_SINK@", muted ? "1" : "0"]).ok
    }

    @discardableResult
    public static func setDefaultSink(id: Int) -> Bool {
        run(["set-default", String(id)]).ok
    }

    // MARK: Parsing (internal for the tests)

    /// "Volume: 0.65" / "Volume: 0.65 [MUTED]" → (0.65, muted).
    static func parseVolume(_ text: String) -> (volume: Double, muted: Bool)? {
        let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard line.hasPrefix("Volume:") else { return nil }
        let rest = line.dropFirst("Volume:".count)
            .trimmingCharacters(in: .whitespaces)
        let parts = rest.split(separator: " ", maxSplits: 1)
        guard let v = Double(parts.first ?? "") else { return nil }
        return (v, rest.contains("MUTED"))
    }

    /// The `Sinks:` subsection of wpctl status's Audio block. The Video
    /// block has a `Sinks:` heading of its own, so parsing stops at the
    /// end of the Audio block rather than at the first heading match.
    ///
    ///     Audio
    ///      ├─ Sinks:
    ///      │  *   55. Family 17h HD Audio Controller Analog Stereo [vol: 0.65]
    ///      │      71. HDMI Audio                                   [vol: 1.00]
    static func parseSinks(fromStatus text: String) -> [AudioSink] {
        var sinks: [AudioSink] = []
        var inAudio = false
        var inSinks = false
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if line == "Audio" { inAudio = true; continue }
            if line == "Video" || line == "Settings" { inAudio = false; inSinks = false; continue }
            guard inAudio else { continue }
            // Subsection headings sit after the tree glyphs ("├─ Sinks:").
            if line.contains("─ ") {
                inSinks = line.hasSuffix("Sinks:")
                continue
            }
            guard inSinks else { continue }
            // " │  *   55. Name ...  [vol: 0.65]" — id and name; the star
            // marks the default. Rows without an id are spacers.
            var body = line
            for glyph in ["│", "*"] {
                body = body.replacingOccurrences(of: glyph, with: " ")
            }
            let trimmed = body.trimmingCharacters(in: .whitespaces)
            guard let dot = trimmed.firstIndex(of: "."),
                  let id = Int(trimmed[trimmed.startIndex..<dot]) else { continue }
            var name = String(trimmed[trimmed.index(after: dot)...])
                .trimmingCharacters(in: .whitespaces)
            if let bracket = name.range(of: "[vol:") {
                name = String(name[name.startIndex..<bracket.lowerBound])
                    .trimmingCharacters(in: .whitespaces)
            }
            guard !name.isEmpty else { continue }
            sinks.append(AudioSink(id: id, name: name,
                                   isDefault: line.contains("*")))
        }
        return sinks
    }

    // MARK: Process

    private static func run(_ args: [String]) -> (ok: Bool, stdout: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/wpctl")
        process.arguments = args
        process.environment = environment()
        let out = Pipe()
        process.standardOutput = out
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        do { try process.run() } catch { return (false, "") }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus == 0,
                String(data: data, encoding: .utf8) ?? "")
    }
}
