// Raw C FFI Test Spike
import Foundation

// C function declarations (matching idl_ffi.h)
@_silgen_name("idl_parse_graph")
func idl_parse_graph(_ path: UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>?

@_silgen_name("idl_free_string")
func idl_free_string(_ ptr: UnsafeMutablePointer<CChar>?)

func testRawCFFI() {
    let testPath = "/nonexistent"
    
    let startTime = CFAbsoluteTimeGetCurrent()
    
    let resultPtr = idl_parse_graph(testPath)
    
    if let resultPtr = resultPtr {
        let result = String(cString: resultPtr)
        print("Raw C FFI result: \(result)")
        idl_free_string(resultPtr)
    }
    
    let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
    print("Raw C FFI call time: \(String(format: "%.2f", elapsed))ms")
}
