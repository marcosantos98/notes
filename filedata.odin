package main

import "base:intrinsics"
import "core:fmt"
import "core:os"
import "core:strings"

/*
nfile spec:

[5]u8 magic
u8 version
u16 current_proj_len
[current_proj_len]u8 current_proj
u16 n_projects
projects:
    u16 p_name_len
    [p_name_len]u8 p_name
    u16 n_notes
    notes 0..n_notes:
	u16 n_title_len
	[n_title_len]u8 n_title
*/

VERSION: u8 : 2

write_u16 :: proc(h: os.Handle, it: u16) {
    os.write_byte(h, auto_cast (it >> 8) & 0xFF)
    os.write_byte(h, auto_cast it & 0xFF)
}

write_str :: proc(h: os.Handle, s: string) {
    write_u16(h, auto_cast len(s))
    os.write_ptr(h, raw_data(s), len(s))
}

save_state :: proc(s: State) {

    np := NOTES_PATH
    if np == "" do np = create_or_use_appdata_path()

    h, ok := os.open(np, os.O_WRONLY | os.O_CREATE)
    if ok != nil {
        fmt.eprintfln("Failed to open `{}`. {}", np, ok)
        return
    }

    os.write_byte(h, 'N')
    os.write_byte(h, 'O')
    os.write_byte(h, 'T')
    os.write_byte(h, 'E')
    os.write_byte(h, 'S')
    os.write_byte(h, VERSION)
    write_str(h, s.current_proj)
    write_u16(h, auto_cast len(s.projs))

    for k, v in s.projs {
        write_str(h, k)
        write_u16(h, auto_cast len(v.notes))
        for n in v.notes {
            write_str(h, n.title)
        }
    }
}

read_u16 :: proc(data: []u8, cursor: ^u32) -> u16 {
    defer cursor^ += 2
    at := cursor^
    return auto_cast ((data[at] << 8) | data[at + 1])
}

read_str :: proc(data: []u8, cursor: ^u32) -> string {
    len := read_u16(data, cursor)
    defer cursor^ += auto_cast len
    return strings.clone_from_bytes(data[cursor^:cursor^ + auto_cast len], context.temp_allocator)
}

create_or_use_appdata_path :: proc() -> string {
    path := os.get_env("appdata", context.temp_allocator)
    notes_path := fmt.tprintf("{}\\notes-global", path)
    if os.exists(notes_path) do return fmt.tprintf("{}\\global.nf", notes_path)

    if err := os.make_directory(notes_path); err != nil {
        panic("ksjdkla")
    }
    return fmt.tprintf("{}\\global.nf", notes_path)
}

check_magic_and_version :: proc(data: []byte) -> (int, NotesError) {
    // version 1 doesn't contain the magic
    has_magic := data[0] == 'N' && data[1] == 'O' && data[2] == 'T' && data[3] == 'E' && data[4] == 'S'
    if !has_magic && data[0] != 1 do return auto_cast data[0], .VX_NO_MAGIC
    if !has_magic && data[0] == 1 do return 1, .NONE

    if data[5] > VERSION do return -1, .INVALID_VERSION

    return auto_cast data[5], .NONE
}

// :volatile(proj)
// :volatile(notes)
// :volatile(state)
load_state_vx :: proc(data: []byte, version: int) -> (State, NotesError) {
    load_version_v1 :: proc(data: []byte) -> State {
        cursor: u32 = 0
        s := State {
            current_proj = read_str(data, &cursor),
            projs        = make(map[string]Proj, context.temp_allocator),
        }

        n_p := read_u16(data, &cursor)
        for _ in 0 ..< n_p {
            p := Proj{}
            p.notes = make([dynamic]Note, context.temp_allocator)
            p.name = read_str(data, &cursor)
            notes_l := read_u16(data, &cursor)
            for _ in 0 ..< notes_l {
                append(&p.notes, Note{read_str(data, &cursor)})
            }
            s.projs[p.name] = p
        }
        return s
    }

    load_version_v2 :: proc(data: []byte) -> State {
        return load_version_v1(data)
    }

    switch version {
    case 1:
        return load_version_v1(data[1:]), .NONE
    case 2:
        return load_version_v2(data[6:]), .NONE
    }

    panic("Unreachable")
}

load_state :: proc() -> (State, NotesError) {

    np := NOTES_PATH
    if np == "" do np = create_or_use_appdata_path()

    data: []byte
    ok: bool
    if data, ok = os.read_entire_file(np, context.temp_allocator); ok {
        if version, err := check_magic_and_version(data); err == .NONE {
            return load_state_vx(data, version)
        } else {
            fmt.panicf("{}, {}", err, version)
        }
    } else {
        // Start with clean state since the file wasn't found.
        return state_init(), .FILE_NOT_FOUND
    }

    panic("Unreachable")
}
