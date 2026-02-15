#+build linux
package main

import "core:fmt"
import "core:os"

nf_get_appdata_path :: proc() -> string {
    path: string
    if path = os.get_env("HOME"); len(path) == 0 do fmt.panicf("$HOME not set in current shell. This is not allowed.")
    path = fmt.tprintf("{}/.local/share/notes", path)
    if !os.exists(path) do if err := os.make_directory(path); err != nil do fmt.panicf("Failed to create local data folder at: {}", path)
    return path
}

nf_create_or_use_appdata_path :: proc() -> string {
    return fmt.tprintf("{}/global.nf", nf_get_appdata_path())
}

nf_lock_path :: proc() -> string {
    return fmt.tprintf("{}/.lock", nf_get_appdata_path())
}
