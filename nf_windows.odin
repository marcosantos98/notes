#+build windows
package main

import "core:fmt"
import "core:os"

nf_create_or_use_appdata_path :: proc() -> string {
    path := os.get_env("appdata", context.temp_allocator)
    notes_path := fmt.tprintf("{}\\notes-global", path)
    if os.exists(notes_path) do return fmt.tprintf("{}\\global.nf", notes_path)

    if err := os.make_directory(notes_path); err != nil {
        panic("ksjdkla")
    }
    return fmt.tprintf("{}\\global.nf", notes_path)
}
