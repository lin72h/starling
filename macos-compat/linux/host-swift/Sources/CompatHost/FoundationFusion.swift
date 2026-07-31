// FoundationFusion — the machold ⇄ Swift-Foundation bridge for serializers.
//
// Real Foundation ObjC classes (NSJSONSerialization / NSPropertyListSerialization) are Swift
// classes on Linux, and machold's from-scratch objc_msgSend can't dispatch to them. So instead
// of reimplementing the parsers in C, machold routes those class methods here: this uses the
// Linux Swift toolchain's robust JSONSerialization / PropertyListSerialization to parse/emit,
// then converts the resulting Swift `Any` tree ⇄ machold-native objects at the boundary (via
// the exported `machold_obj_*` C ABI). The binary only ever sees machold-native collections,
// which its runtime CAN message.
import Foundation
#if canImport(Glibc)
import Glibc
#endif

// ── machold object-model ABI (defined in machold.c, resolved at runtime, RTLD_GLOBAL) ──
@_silgen_name("machold_obj_string")     func mo_string(_ b: UnsafePointer<UInt8>?, _ n: Int) -> UnsafeMutableRawPointer?
@_silgen_name("machold_obj_number_ll")  func mo_num_ll(_ v: Int64) -> UnsafeMutableRawPointer?
@_silgen_name("machold_obj_number_d")   func mo_num_d(_ v: Double) -> UnsafeMutableRawPointer?
@_silgen_name("machold_obj_bool")       func mo_bool(_ b: Int32) -> UnsafeMutableRawPointer?
@_silgen_name("machold_obj_null")       func mo_null() -> UnsafeMutableRawPointer?
@_silgen_name("machold_obj_array")      func mo_array() -> UnsafeMutableRawPointer?
@_silgen_name("machold_obj_array_add")  func mo_array_add(_ a: UnsafeMutableRawPointer?, _ o: UnsafeMutableRawPointer?)
@_silgen_name("machold_obj_dict")       func mo_dict() -> UnsafeMutableRawPointer?
@_silgen_name("machold_obj_dict_set")   func mo_dict_set(_ d: UnsafeMutableRawPointer?, _ k: UnsafeMutableRawPointer?, _ v: UnsafeMutableRawPointer?)
@_silgen_name("machold_obj_data")       func mo_data(_ b: UnsafeRawPointer?, _ n: Int) -> UnsafeMutableRawPointer?

@_silgen_name("machold_obj_type")       func mo_type(_ o: UnsafeMutableRawPointer?) -> Int32
@_silgen_name("machold_obj_str")        func mo_str(_ o: UnsafeMutableRawPointer?) -> UnsafePointer<UInt8>?
@_silgen_name("machold_obj_strlen")     func mo_strlen(_ o: UnsafeMutableRawPointer?) -> Int
@_silgen_name("machold_obj_num_kind")   func mo_num_kind(_ o: UnsafeMutableRawPointer?) -> Int32
@_silgen_name("machold_obj_num_double") func mo_num_double(_ o: UnsafeMutableRawPointer?) -> Double
@_silgen_name("machold_obj_num_ll")     func mo_num_ll_get(_ o: UnsafeMutableRawPointer?) -> Int64
@_silgen_name("machold_obj_arr_count")  func mo_arr_count(_ o: UnsafeMutableRawPointer?) -> Int
@_silgen_name("machold_obj_arr_at")     func mo_arr_at(_ o: UnsafeMutableRawPointer?, _ i: Int) -> UnsafeMutableRawPointer?
@_silgen_name("machold_obj_dict_count") func mo_dict_count(_ o: UnsafeMutableRawPointer?) -> Int
@_silgen_name("machold_obj_dict_key")   func mo_dict_key(_ o: UnsafeMutableRawPointer?, _ i: Int) -> UnsafeMutableRawPointer?
@_silgen_name("machold_obj_dict_val")   func mo_dict_val(_ o: UnsafeMutableRawPointer?, _ i: Int) -> UnsafeMutableRawPointer?
@_silgen_name("machold_obj_data_bytes") func mo_data_bytes(_ o: UnsafeMutableRawPointer?) -> UnsafeRawPointer?
@_silgen_name("machold_obj_data_len")   func mo_data_len(_ o: UnsafeMutableRawPointer?) -> Int

private func ff_string(_ s: String) -> UnsafeMutableRawPointer? {
    let bytes = Array(s.utf8)
    return bytes.withUnsafeBufferPointer { mo_string($0.baseAddress, $0.count) }
}

// Swift `Any` (from JSON/plist parse) → machold-native object tree.
private func swiftToMachold(_ any: Any) -> UnsafeMutableRawPointer? {
    switch any {
    case let s as String:
        return ff_string(s)
    case is NSNull:
        return mo_null()
    case let n as NSNumber:
        let enc = String(cString: n.objCType)
        if enc == "c" || enc == "B" { return mo_bool(n.boolValue ? 1 : 0) }
        if enc == "d" || enc == "f" { return mo_num_d(n.doubleValue) }
        return mo_num_ll(n.int64Value)
    case let b as Bool:
        return mo_bool(b ? 1 : 0)
    case let i as Int:
        return mo_num_ll(Int64(i))
    case let d as Double:
        return mo_num_d(d)
    case let a as [Any]:
        let arr = mo_array()
        for e in a { mo_array_add(arr, swiftToMachold(e)) }
        return arr
    case let dict as [String: Any]:
        let d = mo_dict()   // keys machold-native — machold-native consumers (F3, plutil ObjC key access)
        for (k, v) in dict { mo_dict_set(d, ff_string(k), swiftToMachold(v)) }   // message them; a Swift-bridging
        return d                                                                  // consumer (plutil -p) hits the wall
    case let dict as [AnyHashable: Any]:
        let d = mo_dict()
        for (k, v) in dict { mo_dict_set(d, ff_string(String(describing: k)), swiftToMachold(v)) }
        return d
    case let dat as Data:
        return dat.withUnsafeBytes { mo_data($0.baseAddress, dat.count) }
    default:
        return mo_null()
    }
}

// machold-native object tree → Swift `Any` (for JSON/plist serialize).
private func macholdToSwift(_ p: UnsafeMutableRawPointer?) -> Any {
    guard let p = p else { return NSNull() }
    switch mo_type(p) {
    case 0:
        let n = mo_strlen(p)
        if let b = mo_str(p), n >= 0 { return String(decoding: UnsafeBufferPointer(start: b, count: n), as: UTF8.self) }
        return ""
    case 1:
        switch mo_num_kind(p) {
        case 2:  return NSNumber(value: mo_num_ll_get(p) != 0)
        case 1:  return NSNumber(value: mo_num_double(p))
        default: return NSNumber(value: mo_num_ll_get(p))
        }
    case 2:
        var a = [Any](); let c = mo_arr_count(p)
        for i in 0..<c { a.append(macholdToSwift(mo_arr_at(p, i))) }
        return a
    case 3:
        var d = [String: Any](); let c = mo_dict_count(p)
        for i in 0..<c {
            let k = macholdToSwift(mo_dict_key(p, i))
            d[(k as? String) ?? String(describing: k)] = macholdToSwift(mo_dict_val(p, i))
        }
        return d
    case 4:
        if let b = mo_data_bytes(p) { return Data(bytes: b, count: mo_data_len(p)) }
        return Data()
    default:
        return NSNull()
    }
}

private func copyOut(_ data: Data, _ outLen: UnsafeMutablePointer<Int>?) -> UnsafeMutableRawPointer? {
    let n = data.count
    guard let buf = malloc(n == 0 ? 1 : n) else { return nil }
    if n > 0 { data.withUnsafeBytes { if let base = $0.baseAddress { memcpy(buf, base, n) } } }
    outLen?.pointee = n
    return buf
}

// ── entry points machold's NSJSONSerialization / NSPropertyListSerialization call ──
@_cdecl("machold_fusion_json_parse")
func machold_fusion_json_parse(_ bytes: UnsafeRawPointer?, _ len: Int) -> UnsafeMutableRawPointer? {
    guard let bytes = bytes else { return nil }
    let data = Data(bytes: bytes, count: len)
    guard let obj = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else { return nil }
    return swiftToMachold(obj)
}

@_cdecl("machold_fusion_json_serialize")
func machold_fusion_json_serialize(_ root: UnsafeMutableRawPointer?, _ outLen: UnsafeMutablePointer<Int>?, _ pretty: Int32) -> UnsafeMutableRawPointer? {
    let any = macholdToSwift(root)
    var opts: JSONSerialization.WritingOptions = [.fragmentsAllowed]
    if pretty != 0 { opts.insert(.prettyPrinted); opts.insert(.sortedKeys) }
    guard let data = try? JSONSerialization.data(withJSONObject: any, options: opts) else { return nil }
    return copyOut(data, outLen)
}

@_cdecl("machold_fusion_plist_parse")
func machold_fusion_plist_parse(_ bytes: UnsafeRawPointer?, _ len: Int, _ outFormat: UnsafeMutablePointer<Int32>?) -> UnsafeMutableRawPointer? {
    guard let bytes = bytes else { return nil }
    let data = Data(bytes: bytes, count: len)
    var fmt = PropertyListSerialization.PropertyListFormat.xml
    guard let obj = try? PropertyListSerialization.propertyList(from: data, options: [], format: &fmt) else { return nil }
    outFormat?.pointee = (fmt == .binary) ? 1 : 0
    return swiftToMachold(obj)
}

@_cdecl("machold_fusion_plist_serialize")
func machold_fusion_plist_serialize(_ root: UnsafeMutableRawPointer?, _ binary: Int32, _ outLen: UnsafeMutablePointer<Int>?) -> UnsafeMutableRawPointer? {
    let any = macholdToSwift(root)
    let fmt: PropertyListSerialization.PropertyListFormat = (binary != 0) ? .binary : .xml
    guard let data = try? PropertyListSerialization.data(fromPropertyList: any, format: fmt, options: 0) else { return nil }
    return copyOut(data, outLen)
}

// ── NSDateFormatter, wrapped through the same bridge (dates are miserable to hand-roll) ──
// Formatting defaults to UTC + POSIX locale for deterministic, timezone-stable output (a
// reasonable compat default; explicit -setTimeZone: is future work).
private func ff_dateFormatter(_ fmt: UnsafePointer<UInt8>?, _ fmtLen: Int) -> DateFormatter {
    let df = DateFormatter()
    df.locale = Locale(identifier: "en_US_POSIX")
    df.timeZone = TimeZone(identifier: "UTC")
    if let fmt = fmt, fmtLen > 0 {
        df.dateFormat = String(decoding: UnsafeBufferPointer(start: fmt, count: fmtLen), as: UTF8.self)
    }
    return df
}

@_cdecl("machold_fusion_date_format")
func machold_fusion_date_format(_ ts: Double, _ fmt: UnsafePointer<UInt8>?, _ fmtLen: Int, _ outLen: UnsafeMutablePointer<Int>?) -> UnsafeMutableRawPointer? {
    let s = ff_dateFormatter(fmt, fmtLen).string(from: Date(timeIntervalSince1970: ts))
    return copyOut(Data(s.utf8), outLen)
}

// Real Linux Swift NSData objects (so a Swift+ObjC hybrid's `x as Data` / `as? NSData` casts
// succeed — a machold-native NSData fails the Swift dynamic cast). Returned retained; machold
// reads them back via the foreign-object path (CFDataGetBytePtr/Length).
@_cdecl("machold_fusion_data_from_bytes")
func machold_fusion_data_from_bytes(_ bytes: UnsafeRawPointer?, _ len: Int) -> UnsafeMutableRawPointer? {
    let d = (bytes != nil && len > 0) ? Data(bytes: bytes!, count: len) : Data()
    return Unmanaged.passRetained(d as NSData).toOpaque()
}
@_cdecl("machold_fusion_data_from_file")
func machold_fusion_data_from_file(_ path: UnsafePointer<CChar>?) -> UnsafeMutableRawPointer? {
    guard let path = path,
          let d = try? Data(contentsOf: URL(fileURLWithPath: String(cString: path))) else { return nil }
    return Unmanaged.passRetained(d as NSData).toOpaque()
}

// Returns timeIntervalSince1970, or NaN if the string doesn't parse.
@_cdecl("machold_fusion_date_parse")
func machold_fusion_date_parse(_ str: UnsafePointer<UInt8>?, _ strLen: Int, _ fmt: UnsafePointer<UInt8>?, _ fmtLen: Int) -> Double {
    guard let str = str else { return Double.nan }
    let s = String(decoding: UnsafeBufferPointer(start: str, count: strLen), as: UTF8.self)
    guard let d = ff_dateFormatter(fmt, fmtLen).date(from: s) else { return Double.nan }
    return d.timeIntervalSince1970
}
