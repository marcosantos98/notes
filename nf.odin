package main

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
	u16 tags_len
	[tags_len]string{u16 len, [len]u8} n_tags
*/

NF_VERSION: u8 : 3

@(private)
write_str :: proc(dw: ^DynWriter, s: string) {
    dyn_writer_u16(dw, auto_cast len(s))
    dyn_writer_ptr(dw, raw_data(s), len(s))
}

@(private)
read_u16 :: proc(data: []u8, cursor: ^u32) -> u16 {
    defer cursor^ += 2
    at := cursor^
    return auto_cast ((data[at] << 8) | data[at + 1])
}

@(private)
read_str :: proc(data: []u8, cursor: ^u32) -> string {
    len := read_u16(data, cursor)
    defer cursor^ += auto_cast len
    return strings.clone_from_bytes(data[cursor^:cursor^ + auto_cast len], context.temp_allocator)
}

nf_create_or_use_appdata_path :: proc() -> string {
    path := os.get_env("appdata", context.temp_allocator)
    notes_path := fmt.tprintf("{}\\notes-global", path)
    if os.exists(notes_path) do return fmt.tprintf("{}\\global.nf", notes_path)

    if err := os.make_directory(notes_path); err != nil {
        panic("ksjdkla")
    }
    return fmt.tprintf("{}\\global.nf", notes_path)
}

// :volatile(proj)
// :volatile(notes)
// :volatile(state)
nf_load_state_vx :: proc(path: string, data: []byte, version: int) -> (State, NotesError) {
    load_version_v1 :: proc(path: string, data: []byte) -> State {
        cursor: u32 = 0
        s := State {
            current_proj = read_str(data, &cursor),
            projs        = make(map[string]Proj, context.temp_allocator),
            path         = path,
        }

        n_p := read_u16(data, &cursor)
        for _ in 0 ..< n_p {
            p := Proj{}
            p.notes = make([dynamic]Note, context.temp_allocator)
            p.name = read_str(data, &cursor)
            notes_l := read_u16(data, &cursor)
            for _ in 0 ..< notes_l {
                append(&p.notes, Note{read_str(data, &cursor), make([dynamic]string, context.temp_allocator)})
            }
            s.projs[p.name] = p
        }
        return s
    }

    load_version_v2 :: proc(path: string, data: []byte) -> State {
        return load_version_v1(path, data)
    }

    load_version_v3 :: proc(path: string, data: []byte) -> State {
        cursor: u32 = 0
        s := State {
            current_proj = read_str(data, &cursor),
            projs        = make(map[string]Proj, context.temp_allocator),
            path         = path,
        }

        n_p := read_u16(data, &cursor)
        for _ in 0 ..< n_p {
            p := Proj{}
            p.notes = make([dynamic]Note, context.temp_allocator)
            p.name = read_str(data, &cursor)
            notes_l := read_u16(data, &cursor)
            for _ in 0 ..< notes_l {
                note := read_str(data, &cursor)
                tags_len := read_u16(data, &cursor)
                tags := make([dynamic]string, context.temp_allocator)
                for _ in 0 ..< tags_len {
                    append(&tags, read_str(data, &cursor))
                }
                append(&p.notes, Note{note, tags})
            }
            s.projs[p.name] = p
        }
        return s
    }

    switch version {
    case 1:
        return load_version_v1(path, data[1:]), .NONE
    case 2:
        return load_version_v2(path, data[6:]), .NONE
    case 3:
        return load_version_v3(path, data[6:]), .NONE
    }

    panic("Unreachable")
}

nf_check_magic_get_version :: proc {
    nf_check_magic_get_version_data,
    nf_check_magic_get_version_file,
}

nf_check_magic_get_version_file :: proc(path: string) -> (int, NotesError) {
    data, ok := os.read_entire_file(path, context.temp_allocator)
    if ok do return nf_check_magic_get_version_data(data)
    return -1, .FILE_NOT_FOUND
}

nf_check_magic_get_version_data :: proc(data: []byte) -> (int, NotesError) {
    // version 1 doesn't contain the magic
    has_magic := data[0] == 'N' && data[1] == 'O' && data[2] == 'T' && data[3] == 'E' && data[4] == 'S'
    if !has_magic && data[0] != 1 do return auto_cast data[0], .VX_NO_MAGIC
    if !has_magic && data[0] == 1 do return 1, .NONE

    if data[5] > NF_VERSION do return -1, .INVALID_VERSION

    return auto_cast data[5], .NONE
}

nf_load :: proc(path: string) -> (State, NotesError) {
    data, ok := os.read_entire_file(path, context.temp_allocator)
    if !ok do return {}, .FILE_NOT_FOUND

    if version, err := nf_check_magic_get_version(data); err == .NONE do return nf_load_state_vx(path, data, version)

    panic("unreacheable: nf_load")
}

// :volatile(proj)
// :volatile(notes)
// :volatile(state)
nf_save :: proc(s: State) -> NotesError {

    assert(len(s.path) > 0)

    writer := dyn_writer_init(context.temp_allocator)

    dyn_writer_u8(&writer, 'N')
    dyn_writer_u8(&writer, 'O')
    dyn_writer_u8(&writer, 'T')
    dyn_writer_u8(&writer, 'E')
    dyn_writer_u8(&writer, 'S')
    dyn_writer_u8(&writer, NF_VERSION)

    write_str(&writer, s.current_proj)
    dyn_writer_u16(&writer, auto_cast len(s.projs))

    for k, v in s.projs {
        write_str(&writer, k)
        dyn_writer_u16(&writer, auto_cast len(v.notes))
        for n in v.notes {
            write_str(&writer, n.title)
            dyn_writer_u16(&writer, auto_cast len(n.tags))
            for t in n.tags {
                write_str(&writer, t)
            }
        }
    }

    if !os.write_entire_file(s.path, writer.data[:]) do return .FAILED_TO_SAVE

    return .NONE
}
