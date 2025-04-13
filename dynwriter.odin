package main

DynWriter :: struct {
    data:   [dynamic]u8,
    cursor: u64,
}

dyn_writer_init :: proc(allocator := context.allocator) -> DynWriter {
    return {make([dynamic]u8, allocator), 0}
}

dyn_writer_u8 :: proc(dw: ^DynWriter, it: u8) {
    append(&dw.data, it)
    dw.cursor += 1
}

dyn_writer_u16 :: proc(dw: ^DynWriter, it: u16) {
    dyn_writer_u8(dw, auto_cast (it >> 8) & 0xFF)
    dyn_writer_u8(dw, auto_cast it & 0xFF)
}

dyn_writer_ptr :: proc(dw: ^DynWriter, p: rawptr, len: int) {
    append(&dw.data, ..([^]byte)(p)[:len])
    dw.cursor += auto_cast len
}
