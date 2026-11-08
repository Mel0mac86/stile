#!/bin/bash
# Verifica la logica (modelli, motore outfit, colori, meteo, valigia, backup) fuori da Xcode.
# Sostituisce SwiftData con uno stub (le macro @Model richiedono Xcode) e compila con il toolchain macOS.
# Uso: ./scripts/verify_logic.sh   (richiede Command Line Tools)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
SDK="$(xcrun --show-sdk-path --sdk macosx)"
ARCH="$(uname -m)"

for f in "$ROOT"/MyWardrobeAI/Models/*.swift "$ROOT"/MyWardrobeAI/Services/*.swift; do
  sed -e 's/^@Model$//' -e 's/@Attribute(\.unique) //' -e 's/^import SwiftData$/import Foundation/' \
      -e 's/\.authorizedWhenInUse/.authorizedAlways/g' "$f" > "$WORK/$(basename "$f")"
done
cat > "$WORK/SwiftDataStub.swift" <<'STUB'
import Foundation
struct SortDescriptor<T> { init(_ keyPath: AnyKeyPath, order: Int = 0) {} }
struct FetchDescriptor<T> { init(predicate: Bool? = nil, sortBy: [SortDescriptor<T>] = []) {}; init() {} }
final class ModelContext {
    func fetch<T>(_ d: FetchDescriptor<T>) throws -> [T] { [] }
    func insert<T>(_ m: T) {}
    func delete<T>(_ m: T) {}
    func save() throws {}
}
STUB
cp "$ROOT/scripts/LogicSelfTest.swift" "$WORK/main.swift"

swiftc -sdk "$SDK" -target "$ARCH-apple-macos14.0" "$WORK"/*.swift -o "$WORK/logic-selftest"
"$WORK/logic-selftest"
