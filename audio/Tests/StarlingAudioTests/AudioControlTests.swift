// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Testing
@testable import StarlingAudio

// Fixtures are verbatim wpctl output shapes seen in the wild — a laptop
// with two outputs, and the dev box where the Audio block lists no sinks
// at all (only virtual filters, which must NOT surface as outputs).

private let laptopStatus = """
PipeWire 'pipewire-0' [1.6.2, user@laptop, cookie:1]
 └─ Clients:
        68. wpctl                               [1.6.2, user@laptop, pid:1]

Audio
 ├─ Devices:
 │      52. Family 17h/19h HD Audio Controller  [alsa]
 ├─ Sinks:
 │  *   55. Family 17h/19h HD Audio Controller Analog Stereo [vol: 0.65]
 │      71. HDMI Audio                                       [vol: 1.00 MUTED]
 │
 ├─ Sources:
 │  *   56. Family 17h/19h HD Audio Controller Digital Mic   [vol: 1.00]
 │
 ├─ Filters:
 │
 └─ Streams:

Video
 ├─ Devices:
 ├─ Sinks:
 │      90. Some Video Sink                                  [vol: 1.00]
 └─ Streams:
"""

private let noSinksStatus = """
PipeWire 'pipewire-0' [1.6.2, user@desktop, cookie:2]

Audio
 ├─ Devices:
 │
 ├─ Sinks:
 │
 ├─ Sources:
 │
 ├─ Filters:
 │    - loopback-9910-30
 │  *   35. virtual_mic                                      [Audio/Source]
 │  *   36. vmic_sink                                        [Audio/Sink]
 │
 └─ Streams:

Video
 ├─ Sinks:
 └─ Streams:
"""

@Suite struct VolumeParsing {

    @Test func plainVolume() {
        let p = AudioControl.parseVolume("Volume: 0.65\n")
        #expect(p?.volume == 0.65)
        #expect(p?.muted == false)
    }

    @Test func mutedVolume() {
        let p = AudioControl.parseVolume("Volume: 0.50 [MUTED]\n")
        #expect(p?.volume == 0.50)
        #expect(p?.muted == true)
    }

    @Test func garbageIsNil() {
        #expect(AudioControl.parseVolume("Object '@DEFAULT_AUDIO_SINK@' not found\n") == nil)
        #expect(AudioControl.parseVolume("") == nil)
    }
}

@Suite struct SinkParsing {

    @Test func laptopListsBothOutputs() {
        let sinks = AudioControl.parseSinks(fromStatus: laptopStatus)
        #expect(sinks.count == 2)
        #expect(sinks[0].id == 55)
        #expect(sinks[0].name == "Family 17h/19h HD Audio Controller Analog Stereo")
        #expect(sinks[0].isDefault)
        #expect(sinks[1].id == 71)
        #expect(sinks[1].name == "HDMI Audio")
        #expect(!sinks[1].isDefault)
    }

    @Test func sourcesAndVideoSinksAreNotOutputs() {
        let sinks = AudioControl.parseSinks(fromStatus: laptopStatus)
        // The mic (56) and the Video block's sink (90) must not appear.
        #expect(!sinks.contains { $0.id == 56 })
        #expect(!sinks.contains { $0.id == 90 })
    }

    @Test func virtualFiltersAreNotOutputs() {
        // The dev-box shape: empty Sinks section, virtual filters below it.
        // vmic_sink is tagged [Audio/Sink] but lives under Filters — a
        // picker showing it as a speaker would be a lie.
        let sinks = AudioControl.parseSinks(fromStatus: noSinksStatus)
        #expect(sinks.isEmpty)
    }
}
