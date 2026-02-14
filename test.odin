package main

import "core:os"

import test "core:testing"

T :: test.T

NOTES_PATH :: #config(NOTES_PATH, "")

state_with_test_proj :: proc() -> State {
    s := state_init(NOTES_PATH)
    add_proj(&s, "test")
    nf_save(s)
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
test_cmd_tag_note :: proc(t: ^T) {
    state := state_with_test_proj()
    defer clear_test_state()
    add_note(&state, "test")
    test.expect(t, tag_note(&state, "0", "a"), "Failed to tag note")
    if !test.expect(t, len(state.projs[state.current_proj].notes[0].tags) == 1) {
        test.fail(t)
        return
    }
    test.expect(t, state.projs[state.current_proj].notes[0].tags[0] == "a")
}

@(test)
test_cmd_tag_note_fail_invalid_index :: proc(t: ^T) {
    state := state_with_test_proj()
    test.expect(t, !tag_note(&state, "3", "ad"))
    clear_test_state()
}

@(test)
test_cmd_tag_note_fail_already_contains :: proc(t: ^T) {
    state := state_with_test_proj()
    add_note(&state, "a")
    test.expect(t, tag_note(&state, "0", "b"))
    test.expect(t, !tag_note(&state, "0", "b"))
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

@(test)
test_cmd_mv_note_to_proj :: proc(t: ^T) {
    s := state_with_test_proj()
    add_proj(&s, "test1")
    test.expect(t, add_note(&s, "hello"), "failed to add note")
    test.expect(t, tag_note(&s, "0", "a"), "failed to tag note")
    test.expectf(t, s.current_proj == "test1", "expected `test1` is `{}`", s.current_proj)
    test.expect(t, mv_note_to_proj(&s, "0", "test"), "failed to mv note")
    test.expect(t, len(s.projs[s.current_proj].notes) == 0, "test1 shouldn't contain any notes")
    test.expect(t, len(s.projs["test"].notes) == 1, "test should contain the note moved")
    test.expectf(
        t,
        s.projs["test"].notes[0].title == "hello",
        "test should contain the note `hello` but has `{}`",
        s.projs["test"].notes[0].title,
    )
    test.expect(t, len(s.projs["test"].notes[0].tags) == 1, "The moved note should contain one tag")
    test.expectf(
        t,
        s.projs["test"].notes[0].tags[0] == "a",
        "The moved note should contain tag `a` but has `{}`",
        s.projs["test"].notes[0].tags[0],
    )
    clear_test_state()
}

@(test)
test_cmd_mv_note_fail_invalid_index :: proc(t: ^T) {
    s := state_with_test_proj()
    test.expect(t, !mv_note_to_proj(&s, "a", ""), "Should fail when a number isnt provided!")
    clear_test_state()
}

@(test)
test_cmd_mv_note_fail_index_out_of_range :: proc(t: ^T) {
    s := state_with_test_proj()
    test.expect(t, add_note(&s, "a"), "failed to add note")
    test.expect(t, !mv_note_to_proj(&s, "2", ""), "Should fail since the project only contains one note")

    clear_test_state()
}

@(test)
test_cmd_mv_note_fail_invalid_proj :: proc(t: ^T) {
    s := state_with_test_proj()
    test.expect(t, add_note(&s, "a"), "failed to add note")
    test.expect(t, !mv_note_to_proj(&s, "0", "test1"), "Should fail since the project is invalid")

    clear_test_state()
}
