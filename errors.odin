package main

NotesError :: enum {
    NONE,
    VX_NO_MAGIC,
    FILE_NOT_FOUND,
    INVALID_VERSION,
    FAILED_TO_SAVE,
    FAILED_TO_LOAD,
}

msg_from_err :: proc(err: NotesError) -> string {
    switch err {
    case .NONE:
    case .VX_NO_MAGIC:
        return "Invalid `Notes` file. It may be corrupted."
    case .FILE_NOT_FOUND:
        return "File not found."
    case .INVALID_VERSION:
        return "Invalid version for `Notes` file. It may be corrupted."
    case .FAILED_TO_SAVE:
        return "Couldn't save the state to the working `Notes` file."
    case .FAILED_TO_LOAD:
        return "Couldn't load the state file."
    }
    panic("Unreachable")
}
