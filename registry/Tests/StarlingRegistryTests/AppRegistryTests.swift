// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@testable import StarlingRegistry

/// The registry itself: loading a catalog, merging what app-install recorded,
/// and deciding what counts as installed.
final class AppRegistryTests: XCTestCase {

    private var catalogDir = ""
    private var recordsDir = ""

    override func setUp() {
        super.setUp()
        let base = NSTemporaryDirectory() + "starling-registry-tests-\(getpid())"
        catalogDir = base + "/catalog.d"
        recordsDir = base + "/installed.d"
        for dir in [catalogDir, recordsDir] {
            try? FileManager.default.createDirectory(
                atPath: dir, withIntermediateDirectories: true)
        }
        setenv("STARLING_CATALOG_DIR", catalogDir, 1)
        setenv("STARLING_APP_RECORDS", recordsDir, 1)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(
            atPath: (catalogDir as NSString).deletingLastPathComponent)
        unsetenv("STARLING_CATALOG_DIR")
        unsetenv("STARLING_APP_RECORDS")
        super.tearDown()
    }

    private func writeCatalog(_ name: String, _ body: String) {
        try? body.write(toFile: catalogDir + "/" + name + ".app",
                        atomically: true, encoding: .utf8)
    }

    private func writeRecord(_ name: String, _ body: String) {
        try? body.write(toFile: recordsDir + "/" + name + ".app",
                        atomically: true, encoding: .utf8)
    }

    private func reloaded() -> [AppRecord] {
        AppRegistry.shared.reload()
        return AppRegistry.shared.apps
    }

    // MARK: Loading and ordering

    func testLoadsCatalogInOrder() {
        writeCatalog("b", "[Starling App]\nId=b\nName=Bee\nOrder=20\n")
        writeCatalog("a", "[Starling App]\nId=a\nName=Ay\nOrder=10\n")
        XCTAssertEqual(reloaded().map { $0.id }, ["a", "b"])
    }

    func testRecordsWithoutOrderSortLastByName() {
        writeCatalog("z", "[Starling App]\nId=z\nName=Alpha\n")
        writeCatalog("y", "[Starling App]\nId=y\nName=Beta\n")
        writeCatalog("a", "[Starling App]\nId=a\nName=First\nOrder=1\n")
        XCTAssertEqual(reloaded().map { $0.id }, ["a", "z", "y"])
    }

    // MARK: Installed-ness

    /// An app-install record is what "the store put it there" means, and it
    /// alone is enough — the binary may live somewhere Bins does not list.
    func testRecordAloneMarksAppInstalled() {
        writeCatalog("ghost", "[Starling App]\nId=ghost\nName=Ghost\n"
                            + "Bins=/definitely/not/here\n")
        XCTAssertFalse(reloaded().first!.installed)

        writeRecord("ghost", "[Starling App]\nId=ghost\nWmClass=ghost\n")
        XCTAssertTrue(reloaded().first!.installed)
    }

    /// Installed by hand, outside the store: no record, but the binary is
    /// there. This is every app that predates the registry.
    func testBinsProbeCoversAppsInstalledOutsideTheStore() {
        writeCatalog("sh", "[Starling App]\nId=sh\nName=Shell\nBins=/bin/sh\n")
        XCTAssertTrue(reloaded().first!.installed)
    }

    func testRecordFieldsOverrideCatalogHints() {
        writeCatalog("app", """
            [Starling App]
            Id=app
            Name=App
            Bins=/bin/sh
            WmClass=catalog-guess
            """)
        writeRecord("app", """
            [Starling App]
            Id=app
            WmClass=host-truth
            Version=1.2.3
            """)
        let record = reloaded().first!
        XCTAssertEqual(record.version, "1.2.3")
        // The host's answer is tried first.
        XCTAssertEqual(record.wmClasses.first, "host-truth")
        // ...without losing the catalog's fallback.
        XCTAssertTrue(record.matches(appId: "catalog-guess"))
    }

    /// A path that isn't there must not be handed out: the shell would attempt
    /// a decode per launch and fall back to the glyph anyway.
    func testMissingIconIsDropped() {
        writeCatalog("app", "[Starling App]\nId=app\nName=App\nBins=/bin/sh\n"
                          + "Icon=/no/such/icon.png\n")
        XCTAssertNil(reloaded().first!.iconPath)

        writeCatalog("app", "[Starling App]\nId=app\nName=App\nBins=/bin/sh\n"
                          + "Icon=/bin/sh\n")
        XCTAssertEqual(reloaded().first!.iconPath, "/bin/sh")
    }

    // MARK: Lookup

    func testLookupByAppIdAndTitle() {
        writeCatalog("intellij", """
            [Starling App]
            Id=intellij
            Name=IntelliJ IDEA
            Bins=/bin/sh
            WmClass=jetbrains-idea
            """)
        writeCatalog("zoom", """
            [Starling App]
            Id=zoom
            Name=Zoom
            Bins=/bin/sh
            TitleMatch=Zoom
            """)
        _ = reloaded()
        XCTAssertEqual(AppRegistry.shared.app(forAppId: "jetbrains-idea")?.id,
                       "intellij")
        XCTAssertEqual(AppRegistry.shared.app(forTitle: "Zoom Meeting")?.id, "zoom")
        // The case title matching cannot serve, and must not pretend to.
        XCTAssertNil(AppRegistry.shared.app(forTitle: "untitled – Main.java"))
    }

    func testDefaultDockIsOrderedAndInstalledOnly() {
        writeCatalog("second", "[Starling App]\nId=second\nName=Second\n"
                             + "Bins=/bin/sh\nDock=2\n")
        writeCatalog("first", "[Starling App]\nId=first\nName=First\n"
                            + "Bins=/bin/sh\nDock=1\n")
        writeCatalog("absent", "[Starling App]\nId=absent\nName=Absent\n"
                             + "Bins=/definitely/not/here\nDock=3\n")
        _ = reloaded()
        XCTAssertEqual(AppRegistry.shared.defaultDock.map { $0.id },
                       ["first", "second"])
    }

    // MARK: Parsing helpers

    func testWindowGeometryParsing() {
        let geometry = AppRegistry.geometry("100,60,800,592")
        XCTAssertEqual(geometry?.x, 100)
        XCTAssertEqual(geometry?.height, 592)
        XCTAssertNil(AppRegistry.geometry("100,60,800"))
        XCTAssertNil(AppRegistry.geometry("a,b,c,d"))
        XCTAssertNil(AppRegistry.geometry(nil))
    }

    /// A binary that has been replaced or deleted under a live process is
    /// reported by the kernel as "/path (deleted)". Missing that is how a
    /// running app gets uninstalled out from under itself.
    func testDeletedSuffixIsStrippedFromExePaths() {
        XCTAssertEqual(AppRegistry.stripDeleted("/usr/bin/gimp-3.2 (deleted)"),
                       "/usr/bin/gimp-3.2")
        XCTAssertEqual(AppRegistry.stripDeleted("/usr/bin/gimp-3.2"),
                       "/usr/bin/gimp-3.2")
    }

    /// The running check must match whichever form the launcher exec'd:
    /// /usr/bin/gimp is a symlink to gimp-3.2.
    func testRunningMatchesEitherTheLinkOrItsTarget() {
        writeCatalog("app", "[Starling App]\nId=app\nName=App\nBins=/bin/sh\n")
        _ = reloaded()
        XCTAssertEqual(AppRegistry.shared.runningAppIds(given: ["/bin/sh"]),
                       ["app"])
        XCTAssertEqual(
            AppRegistry.shared.runningAppIds(given: [AppRegistry.resolve("/bin/sh")]),
            ["app"])
        XCTAssertTrue(
            AppRegistry.shared.runningAppIds(given: ["/usr/bin/something"]).isEmpty)
    }
}
