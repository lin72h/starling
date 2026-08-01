// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Testing
@testable import StarlingTime

// The fixture is verbatim `timedatectl show` output from Ubuntu 26.04.
private let showOutput = """
Timezone=America/Los_Angeles
LocalRTC=no
CanNTP=yes
NTP=yes
NTPSynchronized=yes
TimeUSec=Sat 2026-08-01 03:16:05 PDT
RTCTimeUSec=Sat 2026-08-01 03:16:05 PDT
"""

@Suite struct ShowParsing {

    @Test func fullPicture() {
        let s = TimeControl.parseShow(showOutput)
        #expect(s.available)
        #expect(s.timezone == "America/Los_Angeles")
        #expect(s.canNTP)
        #expect(s.ntpEnabled)
        #expect(s.ntpSynchronized)
        #expect(s.localTime == "Sat 2026-08-01 03:16:05 PDT")
    }

    @Test func ntpOffMachine() {
        let s = TimeControl.parseShow("Timezone=UTC\nCanNTP=no\nNTP=no\nNTPSynchronized=no\n")
        #expect(s.timezone == "UTC")
        #expect(!s.canNTP)
        #expect(!s.ntpEnabled)
    }
}

@Suite struct ZoneGrouping {

    private let zones = ["Africa/Abidjan", "Africa/Accra",
                         "America/Los_Angeles", "America/New_York",
                         "Asia/Shanghai", "UTC"]

    @Test func regionsAreUniquePrefixes() {
        #expect(TimeControl.regions(of: zones)
                == ["Africa", "America", "Asia", "UTC"])
    }

    @Test func zonesInRegionKeepFullNames() {
        #expect(TimeControl.zones(zones, inRegion: "America")
                == ["America/Los_Angeles", "America/New_York"])
        // A slashless zone is its own region and must list itself —
        // otherwise UTC becomes a region that offers nothing to pick.
        #expect(TimeControl.zones(zones, inRegion: "UTC") == ["UTC"])
    }
}
