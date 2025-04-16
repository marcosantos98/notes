package main

import "core:c/libc"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:strconv"
import "core:strings"

NOTES_VERSION :: "0.2.1"

// :volatile(notes)
Note :: struct {
    title: string,
    tags:  [dynamic]string,
}

// :volatile(proj)
Proj :: struct {
    notes: [dynamic]Note,
    name:  string,
}

// :volatile(state)
State :: struct {
    projs:        map[string]Proj,
    current_proj: string,

    // transient
    path:         string,
}

// :volatile(state)
state_init :: proc(path := "") -> State {
    return {
        current_proj = "",
        projs = make(map[string]Proj, context.temp_allocator),
        path = path if len(path) != 0 else nf_create_or_use_appdata_path(),
    }
}

// TODO: move
err_expect :: proc(parts: []string, n_args: int, msg: string, args: ..any, exact := false) -> bool {
    if (exact && len(parts) != n_args) || (!exact && len(parts) < n_args) {
        fmt.printfln(msg, ..args)
        return false
    }
    return true
}

// :project
add_proj :: proc(state: ^State, name: string) {
    if name in state.projs {
        fmt.printfln("`{}` already exits.", name)
        fmt.println("Use `sw <name>` to switch to the specified project if you aren't already on it.")
        return
    }

    state.current_proj = name
    p := Proj {
        name  = name,
        notes = make([dynamic]Note, context.temp_allocator),
    }
    state.projs[name] = p
    nf_save(state^)
}

del_proj :: proc(state: ^State, name: string) -> bool {
    if name not_in state.projs {
        fmt.printfln("`{}` isn't a valid project name.", name)
        fmt.println("Use `lsp` to list all projects.")
        return false
    }

    if state.current_proj == name do state.current_proj = ""
    delete_key(&state.projs, name)
    nf_save(state^)
    return true
}

print_project :: proc(state: State) {
    if state.current_proj == "" {
        fmt.println("No project has been created to use `cp`")
        return
    }
    fmt.println("Current project:", state.current_proj)
    fmt.println("   > N of notes:", len(state.projs[state.current_proj].notes))
}

switch_proj :: proc(state: ^State, name: string) -> bool {
    if name not_in state.projs {
        fmt.printfln("`{}` doesn't exist.", name)
        fmt.printfln("Use `np {}` to create the project.", name)
        return false
    }

    state.current_proj = name
    nf_save(state^)
    return true
}

// :volatile(proj)
cpy_proj :: proc(state: ^State, old, new: string) -> Proj {
    proj := state.projs[old]
    cpy := Proj {
        name  = strings.clone(new, context.temp_allocator),
        notes = make([dynamic]Note, context.temp_allocator),
    }
    for n in proj.notes {
        tags := slice.clone_to_dynamic(n.tags[:], context.temp_allocator)
        append(&cpy.notes, Note{strings.clone(n.title, context.temp_allocator), tags})
    }
    return cpy
}

rename_proj :: proc(state: ^State, old, new: string) -> bool {
    if old not_in state.projs {
        fmt.printfln("`{}` isn't a valid project.", old)
        return false
    }

    if state.current_proj == old do state.current_proj = strings.clone(new, context.temp_allocator)

    cpy := cpy_proj(state, old, new)
    delete_key(&state.projs, old)
    state.projs[strings.clone(new, context.temp_allocator)] = cpy
    nf_save(state^)
    return true
}
// ;project

// :note
add_note :: proc(state: ^State, note: string) -> bool {
    if state.current_proj == "" {
        fmt.println("No project has been set to use `addn`")
        return false
    }
    proj := &state.projs[state.current_proj]
    append(&proj.notes, Note{note, make([dynamic]string, context.temp_allocator)})
    nf_save(state^)
    return true
}

rm_note :: proc(state: ^State, idx: string) -> bool {
    if state.current_proj not_in state.projs || state.current_proj == "" {
        fmt.eprintln("Working project not set. Use `sw` to switch to existing one or `np` to create one.")
        return false
    }

    if len(state.projs[state.current_proj].notes) == 0 {
        fmt.eprintln("Can remove when project doesn't contain notes")
        return false
    }

    proj := &state.projs[state.current_proj]
    val, ok := strconv.parse_uint(idx)
    if ok && (val >= 0 && val < len(proj.notes)) {
        ordered_remove(&proj.notes, val)
        nf_save(state^)
        return true
    } else {
        fmt.println("Given argument is not a valid index.")
        return false
    }
    panic("Unreachable")
}

tag_note :: proc(state: ^State, idx, tag: string) -> bool {
    if state.current_proj not_in state.projs || state.current_proj == "" {
        fmt.eprintln("Working project not set. Use `sw` to switch to existing one or `np` to create one.")
        return false
    }

    if len(state.projs[state.current_proj].notes) == 0 {
        fmt.eprintln("Can remove when project doesn't contain notes")
        return false
    }

    proj := &state.projs[state.current_proj]
    val, ok := strconv.parse_uint(idx)
    if ok && (val >= 0 && val < len(proj.notes)) {
        note := &proj.notes[val]
        if _, found := slice.linear_search(note.tags[:], tag); found {
            fmt.eprintfln("Note already contains tag: `{}`.", tag)
            return false
        }
        append(&note.tags, strings.clone(tag, context.temp_allocator))
        nf_save(state^)
        return true
    } else {
        fmt.println("Given argument is not a valid index.")
        return false
    }
    panic("Unreachable")

}

sel_note :: proc(state: ^State, tag: string) -> bool {
    if state.current_proj not_in state.projs || state.current_proj == "" {
        fmt.eprintln("Working project not set. Use `sw` to switch to existing one or `np` to create one.")
        return false
    }

    if len(state.projs[state.current_proj].notes) == 0 {
        fmt.eprintln("Can remove when project doesn't contain notes")
        return false
    }

    fmt.println("selected all with:", tag)
    for n in state.projs[state.current_proj].notes {
        if slice.contains(n.tags[:], tag) {
            fmt.println("-", n.title)
        }
    }

    return true
}

// ;note

print_help :: proc() {
    fmt.printfln("notes {}", NOTES_VERSION)
    fmt.println("    - h | help: print usage.")
    fmt.println("    - exit: exit the tool.")
    fmt.println("")
    fmt.println("    - np <name>: create new project.")
    fmt.println("    - del <name>: delete project.")
    fmt.println("    - rename <old> <new>: rename project.")
    fmt.println("    - cp: print info for current project.")
    fmt.println("    - lsp: list all projects.")
    fmt.println("    - sw <name>: switch current project.")
    fmt.println("")
    fmt.println("    - addn | an | add <note>: add note to current project.")
    fmt.println("    - rn | rm <index>: remove note at given index.")
    fmt.println("    - tag <index> <tag>: tag note at index with given tag.")
    fmt.println("    - sel <tag>: select all with tag.")
    fmt.println("    - ls: list all notes in the current project.")
    fmt.println("    - lsi: list all notes with index in the current project.")
}

interactive_mode :: proc(state: ^State) {
    prompt := make([]byte, 1024, context.temp_allocator)

    this: for true {
        mem.zero(raw_data(prompt), len(prompt))
        fmt.print("> ")
        if libc.fgets(raw_data(prompt), auto_cast len(prompt), libc.stdin) != nil {
            prompt_size := libc.strlen(cstring(raw_data(prompt)))
            fmt.assertf(
                prompt[prompt_size - 1] == '\n',
                "expected new line at end but got {:c} {}",
                prompt[prompt_size],
                prompt[prompt_size],
            )
            prompt_input := string(prompt[:prompt_size - 1])
            prompt_parts := strings.split(prompt_input, " ", context.temp_allocator)
            switch prompt_parts[0] {
            case "exit":
                break this
            case "rename":
                err_expect(
                    prompt_parts[1:],
                    2,
                    "`rename` expects project name and the new name. `rename <old> <new>`.",
                    exact = true,
                ) or_break
                rename_proj(state, prompt_parts[1], prompt_parts[2])
            case "an":
                fallthrough
            case "add":
                fallthrough
            case "addn":
                err_expect(prompt_parts[1:], 1, "addn expects at least one argument") or_break
                add_note(state, strings.join(prompt_parts[1:], " ", context.temp_allocator))
            case "np":
                err_expect(prompt_parts[1:], 1, "`np` expects one argument. `np <title>`", exact = true) or_break
                add_proj(state, strings.clone(prompt_parts[1], context.temp_allocator))
            case "ls":
                if state.current_proj == "" {
                    fmt.println("No project has been set. Use `sw <name>` to set the project.")
                    break
                }
                fmt.printfln("ls {}:", state.current_proj)
                for n in state.projs[state.current_proj].notes {
                    fmt.println("-", n.title)
                    if len(n.tags) > 0 {
                        fmt.print("  tags: ")
                        for t, idx in n.tags {
                            fmt.printf("[{}]", t)
                            if idx != len(n.tags) - 1 {
                                fmt.print(" ")
                            }
                        }
                        fmt.println()
                    }
                }
            case "lsp":
                for k, _ in state.projs {
                    fmt.println("-", k)
                }
            case "lsi":
                for n, i in state.projs[state.current_proj].notes {
                    fmt.printfln("[{}] {}", i, n.title)
                }
            case "sel":
                err_expect(prompt_parts[1:], 1, "`sel` requires the tag. `sel test`.")
                sel_note(state, prompt_parts[1])
            case "rm":
                fallthrough
            case "rn":
                err_expect(prompt_parts[1:], 1, "`rn` requires the index of the note. use `lsi` to get it")
                rm_note(state, prompt_parts[1])
            case "sw":
                err_expect(
                    prompt_parts[1:],
                    1,
                    "`sw` expects at least one argument. `sw <project name>`",
                    exact = true,
                )
                switch_proj(state, strings.clone(prompt_parts[1], context.temp_allocator))
            case "cp":
                print_project(state^)
            case "del":
                err_expect(prompt_parts[1:], 1, "`del` requires an argument. `del <project name>`")
                del_proj(state, prompt_parts[1])
            case "tag":
                err_expect(
                    prompt_parts[1:],
                    2,
                    "`tag` requires index of note and tag. You can get the index from `lsi` command. `tag <index> <tag>`",
                    exact = true,
                )
                tag_note(state, prompt_parts[1], prompt_parts[2])
            case "backup":
                when ODIN_DEBUG {
                    copy_file :: proc(file, to: string) -> bool {
                        data := os.read_entire_file_from_filename(file, context.temp_allocator) or_return
                        os.write_entire_file(to, data) or_return
                        return true
                    }
                    copy_file(state.path, fmt.tprintf("{}.backup", state.path))
                }
            case "h":
                fallthrough
            case "help":
                print_help()
            case:
                fmt.printfln("`{}` not a command", prompt_input)
            }
        }
    }
}

execute_commands :: proc(state: ^State) {

    on_add :: proc(state: ^State, args: []string) -> (bool, int) {
        assert(args[0] == "add")
        if len(args) < 2 {
            fmt.println("`add` requires a string afterwards.")
            return false, 0
        }
        return add_note(state, args[1]), 2
    }

    on_ls :: proc(state: ^State, args: []string) -> (bool, int) {
        assert(args[0] == "ls")
        for n in state.projs[state.current_proj].notes {
            fmt.println("-", n.title)
        }
        return true, 1
    }

    on_lsp :: proc(state: ^State, args: []string) -> (bool, int) {
        assert(args[0] == "lsp")
        for k, _ in state.projs {
            fmt.println("-", k)
        }
        return true, 1
    }

    on_p :: proc(state: ^State, args: []string) -> (bool, int) {
        assert(args[0] == "p")
        if len(args) < 2 {
            fmt.println("`p` requires the name of the project to switch to.")
            return false, 0
        }
        return switch_proj(state, args[1]), 2
    }

    on_help :: proc(state: ^State, args: []string) -> (bool, int) {
        assert(args[0] == "h" || args[0] == "help")
        fmt.println("notes", NOTES_VERSION)
        fmt.println("Usage: notes <cmds>...")
        fmt.println("Commands:")
        fmt.println("    add: add note to current working project. `notes add \"this is a note\"`.")
        fmt.println("     ls: print all notes in the current working project. `notes ls`.")
        fmt.println("    lsp: print all projects in global state. `notes lsp`.")
        fmt.println("      p: change the current working project to the specified one. `notes p test_project`.")
        fmt.println("     cp: print information about current working project in the global state. `notes cp`.")
        fmt.println("   open: open the given notes file instead of global. `notes open <filepath>.nf`")
        fmt.println("     nl: don't open local `Notes` file if available, instead use the global file. `notes nl`")
        fmt.println()
        fmt.println("INFO: Commands can be chained and they will be executed in order.")
        fmt.println("    > `notes p other_project add \"test note\" ls")
        fmt.println("      ^")
        fmt.println(
            "      The command above changes to `other_project`, adds a new note and prints all the current notes in the specified project.",
        )
        return true, len(args)
    }

    on_cp :: proc(state: ^State, args: []string) -> (bool, int) {
        // :volatile(project)
        assert(args[0] == "cp")
        print_project(state^)
        return true, 1
    }

    on_nl :: proc(state: ^State, args: []string) -> (bool, int) {
        assert(args[0] == "nl")
        err: NotesError
        state^, err = nf_load(nf_create_or_use_appdata_path())
        return true, 1
    }

    cmds := make(map[string]proc(state: ^State, args: []string) -> (bool, int), context.temp_allocator)
    cmds["add"] = on_add
    cmds["ls"] = on_ls
    cmds["lsp"] = on_lsp
    cmds["p"] = on_p
    cmds["h"] = on_help
    cmds["help"] = on_help
    cmds["cp"] = on_cp
    cmds["nl"] = on_nl
    // :volatile(on_help)

    for i := 1; i < len(os.args); {
        arg := os.args[i]
        if arg in cmds {
            fmt.println(">", arg)
            res, n := cmds[arg](state, os.args[i:])
            if !res do break
            i += n
            continue
        } else {
            fmt.printfln("`{}` not a valid command. `note h | help` to display the available commands.", arg)
            break
        }
        i += 1
    }
}

has_open_cmd :: proc() -> (path: string, ok: bool) {
    idx := slice.linear_search(os.args[:], "open") or_return
    if len(os.args) > idx + 1 do return os.args[idx + 1], true
    return
}

has_local_file :: proc() -> (string, bool) {
    if files, err := filepath.glob(
        fmt.tprintf("{}\\*.nf", os.get_current_directory(context.temp_allocator)),
        context.temp_allocator,
    ); err == nil && len(files) == 1 {
        if _, err := nf_check_magic_get_version(files[0]); err != .NONE {
            fmt.printfln("[Error] Failed checking magic for {}: {}", files[0], msg_from_err(err))
            return "", false
        }
        return files[0], true
    }
    return "", false
}

main :: proc() {

    nf_path: string
    has_open: bool
    if path, ok := has_open_cmd(); ok {
        nf_path = path
        has_open = ok
    } else if local_path, has_local := has_local_file(); has_local {
        nf_path = local_path
    } else {
        nf_path = nf_create_or_use_appdata_path()
    }

    fmt.println("notes version:", NOTES_VERSION)

    state: State
    err: NotesError
    if state, err = nf_load(nf_path); err != .NONE {
        fmt.printfln("[ERROR]: Failed to load {}: {}", nf_path, msg_from_err(err))
        return
    }

    fmt.println("working path:", nf_path)

    if len(os.args) == 1 || has_open {
        if len(state.projs) == 0 {
            fmt.println("Currently no projects have been create.")
            fmt.println("Use `np <name>` to create a new project.")
        } else if state.current_proj != "" {
            fmt.println("Current working project:", state.current_proj)
        }
        interactive_mode(&state)
        return
    }

    execute_commands(&state)
}
