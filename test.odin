package main

import "core:os"

import test "core:testing"

T :: test.T

NOTES_PATH :: #config(NOTES_PATH, "")

state_with_test_proj :: proc() -> State {
    s := state_init(NOTES_PATH)
    nf_save(s)
    add_proj(&s, "test")
    return s
}

clear_test_state :: proc() {
    if os.exists("./test.bin") {
        os.remove("./test.bin")
    }
}

@(test)
test_cmd_np :: proc(t: ^T) {
    state := state_with_test_proj()

    test.expectf(
        t,
        state.current_proj == "test",
        "`np` should set the state.current_proj to the newly created one. current_proj should be `test` but is `{}`",
        state.current_proj,
    )

    test.expectf(t, "test" in state.projs, "state should contain `test` project after `np`")
    clear_test_state()
}

@(test)
test_cmd_del :: proc(t: ^T) {
    state := state_with_test_proj()
    del_proj(&state, "test")
    test.expect(t, state.current_proj == "", "`del` should set the current proj to empty")
    test.expect(t, "test" not_in state.projs, "the state shouldnt contain the deleted project")
    clear_test_state()
}

@(test)
test_cmd_del_not_current_project :: proc(t: ^T) {
    state := state_with_test_proj()
    add_proj(&state, "te")
    test.expect(t, del_proj(&state, "test"), "del shouldnt fail")
    test.expect(
        t,
        state.current_proj == "te",
        "deleting a proj that isnt the current should reset the state current project",
    )
    clear_test_state()
}

@(test)
test_cmd_del_fail_not_valid_name :: proc(t: ^T) {
    state := state_init()
    test.expect(t, !del_proj(&state, "slkda"), "del should fail when deleting invalid project")
    clear_test_state()
}

@(test)
test_cmd_rename :: proc(t: ^T) {
    state := state_with_test_proj()
    add_note(&state, "a")
    rename_proj(&state, "test", "a")
    test.expect(t, state.current_proj == "a", "renaming the current_proj should reset the current_proj")
    test.expect(t, "test" not_in state.projs, "renaming should delete the old proj")
    proj := state.projs["a"]
    test.expect(t, proj.name == "a", "the renamed proj should contain the new name")
    test.expect(
        t,
        len(proj.notes) == 1 && proj.notes[0].title == "a",
        "renamed project should contain one note with content being `a`",
    )
    clear_test_state()
}

@(test)
test_cmd_rename_fail_invalid_proj :: proc(t: ^T) {
    state := state_init()
    test.expect(t, !rename_proj(&state, "a", "b"), "rename should fail on invalid project")
}

@(test)
test_cmd_rename_not_current_project :: proc(t: ^T) {
    state := state_with_test_proj()
    add_proj(&state, "a")
    rename_proj(&state, "test", "b")
    test.expect(
        t,
        state.current_proj == "a",
        "rename doesnt reset current project if the renamed project isnt the current project",
    )
    clear_test_state()
}

@(test)
test_cmd_sw :: proc(t: ^T) {
    state := state_with_test_proj()
    add_proj(&state, "a")
    test.expect(t, state.current_proj == "a")
    test.expect(t, switch_proj(&state, "test"))
    test.expect(t, state.current_proj == "test")
    clear_test_state()
}

@(test)
test_cmd_sw_fail_invalid :: proc(t: ^T) {
    state := state_with_test_proj()
    test.expect(t, !switch_proj(&state, "a"))
    clear_test_state()
}

@(test)
test_cmd_add_note_fail_no_project :: proc(t: ^T) {
    state := state_init()
    test.expectf(t, !add_note(&state, "test"), "`addn` should fail when the current proj isn't set")
    clear_test_state()
}

@(test)
test_cmd_add_note :: proc(t: ^T) {
    state := state_with_test_proj()
    add_note(&state, "test")

    test.expect(
        t,
        state.projs[state.current_proj].notes[0].title == "test",
        "the current proj should contain a note with `test`",
    )
    clear_test_state()
}

@(test)
test_cmd_rm_note_fail_no_project :: proc(t: ^T) {
    state := state_init()
    test.expect(t, !rm_note(&state, "0"), "`rn` should fail when the current_proj isnt set")
    clear_test_state()
}

@(test)
test_cmd_rm_note_fail_invalid_index :: proc(t: ^T) {
    state := state_with_test_proj()
    add_note(&state, "test")
    test.expect(t, !rm_note(&state, "2"), "`rn` should fail on invalid index")
    test.expect(t, !rm_note(&state, "sadksajd"), "`rn` should fail on invalid input (nan)")
    clear_test_state()
}

@(test)
test_cmd_rm_note :: proc(t: ^T) {
    state := state_with_test_proj()
    add_note(&state, "test")
    test.expect(t, rm_note(&state, "0"), "rm_note shouldn't fail with the current conditions")
    test.expectf(
        t,
        len(state.projs[state.current_proj].notes) == 0,
        "project `test` shouldn't contain notes after `rn`. len is {}",
        len(state.projs[state.current_proj].notes),
    )
    clear_test_state()
}

@(test)
test_save_load :: proc(t: ^T) {
    s := state_with_test_proj()
    add_note(&s, "a")
    add_proj(&s, "b")
    ss, err := nf_load(NOTES_PATH)
    test.expect(t, err == .NONE)
    test.expectf(t, ss.current_proj == s.current_proj, "loaded `{}` != saved `{}`", ss.current_proj, s.current_proj)
    test.expect(t, len(ss.projs) == len(s.projs))
    test.expect(t, "b" in ss.projs)
    test.expect(t, ss.projs["test"].notes[0].title == "a")
    clear_test_state()
}
