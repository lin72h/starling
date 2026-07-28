// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

#if os(Linux)
import Foundation
import PdfiumBridge

/// A PDFium-backed document. PDFium is not thread-safe — every call happens
/// on the main thread (rendering a page takes ~10-50 ms, well under a frame
/// budget hiccup worth optimizing later).
final class PdfDocument {
    private let doc: FPDF_DOCUMENT
    let pageCount: Int

    // Interactive form (AcroForm) environment. `formInfo` must outlive the
    // form handle; `formPage` keeps the page that holds field focus open —
    // closing it between events would drop the focus PDFium tracks.
    private var form: FPDF_FORMHANDLE? = nil
    private var formInfo: UnsafeMutablePointer<FPDF_FORMFILLINFO>? = nil
    private var formPage: (index: Int, page: FPDF_PAGE)? = nil
    /// Button toggles by point, applied to the dictionaries at save time —
    /// PDFium's widget session holds these values but never commits them
    /// for flag-less multi-kid /Btn groups (kill-focus rolls them back).
    private var pendingButtons: [(page: Int, x: Double, y: Double, checked: Bool)] = []

    // Main-thread only (like every other PDFium call here).
    nonisolated(unsafe) private static var libraryInitialized = false
    private static func ensureLibrary() {
        if !libraryInitialized {
            FPDF_InitLibrary()
            libraryInitialized = true
        }
    }

    init?(path: String) {
        Self.ensureLibrary()
        guard let handle = FPDF_LoadDocument(path, nil) else { return nil }
        doc = handle
        pageCount = Int(FPDF_GetPageCount(handle))

        let info = UnsafeMutablePointer<FPDF_FORMFILLINFO>.allocate(capacity: 1)
        info.initialize(to: FPDF_FORMFILLINFO())   // all callbacks optional
        info.pointee.version = 1
        formInfo = info
        form = FPDFDOC_InitFormFillEnvironment(handle, info)
        if let form {
            FPDF_SetFormFieldHighlightColor(form, 0, 0x33B5E5)
            FPDF_SetFormFieldHighlightAlpha(form, 60)
        }
    }

    deinit {
        _closeFormPage()
        if let form {
            FPDFDOC_ExitFormFillEnvironment(form)
        }
        formInfo?.deallocate()
        FPDF_CloseDocument(doc)
    }

    var hasForm: Bool {
        form != nil && FPDF_GetFormType(doc) != FORMTYPE_NONE
    }

    private func _closeFormPage() {
        if let cached = formPage {
            if let form { FORM_OnBeforeClosePage(cached.page, form) }
            FPDF_ClosePage(cached.page)
            formPage = nil
        }
    }

    /// The page that owns form focus, kept open across events.
    private func _formPage(_ index: Int) -> FPDF_PAGE? {
        if let cached = formPage, cached.index == index { return cached.page }
        _closeFormPage()
        guard let page = FPDF_LoadPage(doc, Int32(index)) else { return nil }
        if let form { FORM_OnAfterLoadPage(page, form) }
        formPage = (index, page)
        return page
    }

    // MARK: - Form interaction (coords in unrotated page points)

    /// FPDF_FORMFIELD_* type at the point, or -1 when there is none.
    func formFieldType(page index: Int, x: Double, y: Double) -> Int {
        guard let form, let page = _formPage(index) else { return -1 }
        return Int(FPDFPage_HasFormFieldAtPoint(form, page, x, y))
    }

    func formClick(page index: Int, x: Double, y: Double) {
        guard let form, let page = _formPage(index) else { return }
        // A raw click doesn't transfer focus between widgets in this
        // environment — focus explicitly first (harmless when unfocused).
        FORM_OnFocus(form, page, 0, x, y)
        FORM_OnLButtonDown(form, page, 0, x, y)
        FORM_OnLButtonUp(form, page, 0, x, y)
    }

    /// Select the focused text field's entire contents.
    func formSelectAll(page index: Int) {
        guard let form, let page = _formPage(index) else { return }
        FORM_SelectAllText(form, page)
    }

    private func _isChecked(_ page: FPDF_PAGE, x: Double, y: Double) -> Bool {
        guard let form else { return false }
        var point = FS_POINTF(x: Float(x), y: Float(y))
        guard let annot = FPDFAnnot_GetFormFieldAtPoint(form, page, &point) else {
            return false
        }
        defer { FPDFPage_CloseAnnot(annot) }
        return FPDFAnnot_IsChecked(form, annot) != 0
    }

    /// Toggle a checkbox/radio. Tries the interactive event path first
    /// (click, then focus + space); if the widget still hasn't flipped —
    /// the event route is inert in this headless-FFI setup — writes /AS
    /// and /V on the widget dictionary directly, which is what the events
    /// would have done.
    func formToggleCheck(page index: Int, x: Double, y: Double) {
        guard let form, let page = _formPage(index) else { return }
        let before = _isChecked(page, x: x, y: y)
        FORM_OnLButtonDown(form, page, 0, x, y)
        FORM_OnLButtonUp(form, page, 0, x, y)
        if _isChecked(page, x: x, y: y) == before {
            // The click only re-focused (focus was elsewhere): focus the
            // widget explicitly and toggle with a space keystroke.
            FORM_OnFocus(form, page, 0, x, y)
            FORM_OnChar(form, page, 32, 0)
        }
        // Do NOT kill focus here: on flag-less /Btn groups that rolls the
        // toggle back. Remember the target state for save time instead.
        pendingButtons.append((page: index, x: x, y: y, checked: !before))
    }

    /// Write a button widget's state straight into its dictionary: /V,
    /// /AS, and a font-free direct /N appearance (renders in any viewer
    /// regardless of the AP-state machinery).
    private func _forceButtonState(page index: Int, x: Double, y: Double,
                                   checked: Bool) {
        guard let form, let page = _formPage(index) else { return }
        var annotHandle: FPDF_ANNOTATION? = nil
        let count = FPDFPage_GetAnnotCount(page)
        for i in 0 ..< count {
            guard let candidate = FPDFPage_GetAnnot(page, i) else { continue }
            var rect = FS_RECTF()
            if FPDFAnnot_GetSubtype(candidate) == FPDF_ANNOT_WIDGET,
               FPDFAnnot_GetRect(candidate, &rect) != 0,
               Float(x) >= rect.left, Float(x) <= rect.right,
               Float(y) >= rect.bottom, Float(y) <= rect.top {
                annotHandle = candidate
                break
            }
            FPDFPage_CloseAnnot(candidate)
        }
        guard let annot = annotHandle else { return }
        defer { FPDFPage_CloseAnnot(annot) }
        let content: String
        var valueName: String
        if checked {
            var rect = FS_RECTF()
            FPDFAnnot_GetRect(annot, &rect)
            let left = Double(rect.left)
            let bottom = Double(rect.bottom)
            let width = Double(rect.right) - left
            let height = Double(rect.top) - bottom
            let x1 = left + width * 0.20, y1 = bottom + height * 0.52
            let x2 = left + width * 0.42, y2 = bottom + height * 0.25
            let x3 = left + width * 0.80, y3 = bottom + height * 0.78
            content = String(
                format: "q 0 0 0 RG %.1f w %.2f %.2f m %.2f %.2f l %.2f %.2f l S Q",
                max(1.2, width * 0.12), x1, y1, x2, y2, x3, y3)
            var buffer = [UInt16](repeating: 0, count: 64)
            let len = FPDFAnnot_GetFormFieldExportValue(
                form, annot, &buffer, UInt(buffer.count * 2))
            valueName = len >= 2
                ? String(decoding: buffer.prefix(Int(len) / 2 - 1),
                         as: UTF16.self)
                : "Yes"
            if valueName.isEmpty { valueName = "Yes" }
        } else {
            content = "q Q"
            valueName = "Off"
        }
        var wideContent = Array(content.utf16)
        wideContent.append(0)
        FPDFAnnot_SetAP(annot, FPDF_ANNOT_APPEARANCEMODE_NORMAL, &wideContent)
        var wideValue = Array(valueName.utf16)
        wideValue.append(0)
        FPDFAnnot_SetStringValue(annot, "AS", &wideValue)
        FPDFAnnot_SetStringValue(annot, "V", &wideValue)
    }

    /// UTF-16 code unit into the focused field (8 = backspace, 13 = enter).
    func formChar(page index: Int, _ code: Int) {
        guard let form, let page = _formPage(index) else { return }
        FORM_OnChar(form, page, Int32(code), 0)
    }

    /// Windows virtual-key code (0x25 left, 0x27 right, 0x2E delete).
    func formKey(page index: Int, _ vk: Int) {
        guard let form, let page = _formPage(index) else { return }
        FORM_OnKeyDown(form, page, Int32(vk), 0)
        FORM_OnKeyUp(form, page, Int32(vk), 0)
    }

    /// Commit the in-edit field value (call before saving / on Escape).
    func killFormFocus() {
        if let form { FORM_ForceToKillFocus(form) }
    }

    /// Page size in PDF points (1/72 inch).
    func pageSize(_ index: Int) -> (width: Double, height: Double) {
        var size = FS_SIZEF()
        FPDF_GetPageSizeByIndexF(doc, Int32(index), &size)
        return (Double(size.width), Double(size.height))
    }

    // MARK: - Annotations

    /// Page rotation (0-3, quarter turns clockwise).
    func pageRotation(_ index: Int) -> Int {
        guard let page = FPDF_LoadPage(doc, Int32(index)) else { return 0 }
        defer { FPDF_ClosePage(page) }
        return Int(FPDFPage_GetRotation(page))
    }

    /// Add a highlight annotation. Rect in unrotated page points.
    func addHighlight(page index: Int,
                      minX: Double, minY: Double,
                      maxX: Double, maxY: Double) -> Bool {
        guard let page = FPDF_LoadPage(doc, Int32(index)) else { return false }
        defer { FPDF_ClosePage(page) }
        guard let annot = FPDFPage_CreateAnnot(page, FPDF_ANNOT_HIGHLIGHT) else {
            return false
        }
        defer { FPDFPage_CloseAnnot(annot) }
        var rect = FS_RECTF(left: Float(minX), top: Float(maxY),
                            right: Float(maxX), bottom: Float(minY))
        FPDFAnnot_SetRect(annot, &rect)
        // Highlights only render where their quadpoints are.
        var quad = FS_QUADPOINTSF(
            x1: Float(minX), y1: Float(maxY),
            x2: Float(maxX), y2: Float(maxY),
            x3: Float(minX), y3: Float(minY),
            x4: Float(maxX), y4: Float(minY))
        FPDFAnnot_AppendAttachmentPoints(annot, &quad)
        FPDFAnnot_SetColor(annot, FPDFANNOT_COLORTYPE_Color, 255, 214, 51, 165)
        return true
    }

    /// Add a freehand ink annotation. Points in unrotated page points.
    func addInk(page index: Int, points: [(x: Double, y: Double)]) -> Bool {
        guard points.count >= 2,
              let page = FPDF_LoadPage(doc, Int32(index)) else { return false }
        defer { FPDF_ClosePage(page) }
        guard let annot = FPDFPage_CreateAnnot(page, FPDF_ANNOT_INK) else {
            return false
        }
        defer { FPDFPage_CloseAnnot(annot) }
        var stroke = points.map { FS_POINTF(x: Float($0.x), y: Float($0.y)) }
        guard FPDFAnnot_AddInkStroke(annot, &stroke,
                                     stroke.count) >= 0 else { return false }
        let pad = 4.0
        var rect = FS_RECTF(
            left: Float(points.map(\.x).min()! - pad),
            top: Float(points.map(\.y).max()! + pad),
            right: Float(points.map(\.x).max()! + pad),
            bottom: Float(points.map(\.y).min()! - pad))
        FPDFAnnot_SetRect(annot, &rect)
        FPDFAnnot_SetColor(annot, FPDFANNOT_COLORTYPE_Color, 224, 49, 49, 255)
        FPDFAnnot_SetBorder(annot, 0, 0, 2.2)
        return true
    }

    // MARK: - Modification (all main-thread, like everything else here)

    /// Rotate a page 90° clockwise (persisted on save).
    func rotatePage(_ index: Int) {
        guard let page = FPDF_LoadPage(doc, Int32(index)) else { return }
        FPDFPage_SetRotation(page, (FPDFPage_GetRotation(page) + 1) % 4)
        FPDF_ClosePage(page)
    }

    func deletePage(_ index: Int) {
        FPDFPage_Delete(doc, Int32(index))
    }

    /// Move a page to a new index. Returns false when PDFium refuses.
    func movePage(_ index: Int, to dest: Int) -> Bool {
        var pages: [Int32] = [Int32(index)]
        return FPDF_MovePages(doc, &pages, 1, Int32(dest)) != 0
    }

    /// Serialize the whole document. Buffered in memory first so writing
    /// over the file the document was loaded from is safe (PDFium still
    /// reads the source during FPDF_SaveAsCopy).
    nonisolated(unsafe) private static var _saveBuffer = Data()
    func save(to path: String) -> Bool {
        // Commit an in-edit TEXT field by dropping focus (safe for text;
        // buttons would roll back instead — their state is applied below).
        if let form {
            var pageIndex: Int32 = -1
            var focused: FPDF_ANNOTATION? = nil
            if FORM_GetFocusedAnnot(form, &pageIndex, &focused) != 0,
               let focused {
                let fieldType = FPDFAnnot_GetFormFieldType(form, focused)
                FPDFPage_CloseAnnot(focused)
                if fieldType == 6 || fieldType == 4 {
                    FORM_ForceToKillFocus(form)
                }
            }
        }
        for pending in pendingButtons {
            _forceButtonState(page: pending.page, x: pending.x, y: pending.y,
                              checked: pending.checked)
        }
        Self._saveBuffer = Data()
        var writer = FPDF_FILEWRITE(
            version: 1,
            WriteBlock: { _, data, size in
                if let data, size > 0 {
                    PdfDocument._saveBuffer.append(
                        Data(bytes: data, count: Int(size)))
                }
                return 1
            })
        let ok = withUnsafeMutablePointer(to: &writer) {
            FPDF_SaveAsCopy(doc, $0, FPDF_DWORD(FPDF_NO_INCREMENTAL))
        }
        guard ok != 0 else { return false }
        do {
            try Self._saveBuffer.write(to: URL(fileURLWithPath: path),
                                       options: .atomic)
            Self._saveBuffer = Data()
            pendingButtons = []
            return true
        } catch {
            Self._saveBuffer = Data()
            return false
        }
    }

    /// Render a page to a BGRA byte buffer at the given pixel dimensions
    /// (white background, annotations included).
    func render(page index: Int, width: Int, height: Int) -> [UInt8]? {
        guard width > 0, height > 0 else { return nil }
        // Reuse the focus-holding page handle when rendering that page;
        // transient pages get the form load/close bracket so widgets on
        // every page draw correctly.
        let page: FPDF_PAGE
        var transient: FPDF_PAGE? = nil
        if let cached = formPage, cached.index == index {
            page = cached.page
        } else {
            guard let loaded = FPDF_LoadPage(doc, Int32(index)) else { return nil }
            if let form { FORM_OnAfterLoadPage(loaded, form) }
            transient = loaded
            page = loaded
        }
        defer {
            if let transient {
                if let form { FORM_OnBeforeClosePage(transient, form) }
                FPDF_ClosePage(transient)
            }
        }
        guard let bitmap = FPDFBitmap_Create(Int32(width), Int32(height), 0) else {
            return nil
        }
        defer { FPDFBitmap_Destroy(bitmap) }
        FPDFBitmap_FillRect(bitmap, 0, 0, Int32(width), Int32(height), 0xFFFFFFFF)
        FPDF_RenderPageBitmap(bitmap, page, 0, 0, Int32(width), Int32(height),
                              0, Int32(FPDF_ANNOT))
        if let form {
            FPDF_FFLDraw(form, bitmap, page, 0, 0, Int32(width), Int32(height),
                         0, Int32(FPDF_ANNOT))
        }
        guard let buffer = FPDFBitmap_GetBuffer(bitmap) else { return nil }
        let stride = Int(FPDFBitmap_GetStride(bitmap))
        let src = buffer.assumingMemoryBound(to: UInt8.self)
        var out = [UInt8](repeating: 0, count: width * height * 4)
        out.withUnsafeMutableBytes { dst in
            let base = dst.baseAddress!
            for row in 0 ..< height {
                memcpy(base + row * width * 4, src + row * stride, width * 4)
            }
            // The bitmap is BGRx (created with alpha=0): the 4th byte is
            // undefined — the form-widget draw path leaves zeros there,
            // which a BGRA decode treats as fully transparent (blank page).
            let bytes = base.assumingMemoryBound(to: UInt8.self)
            var offset = 3
            let total = width * height * 4
            while offset < total {
                bytes[offset] = 0xFF
                offset += 4
            }
        }
        return out
    }
}
#endif
