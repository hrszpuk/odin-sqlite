package sqlite3_helpers

import sql ".."
import "core:fmt"

check :: proc{
    check_panic,
    checK_panic_msg,
    check_proc,
    check_proc_args,
}

check_panic :: proc(err: sql.ResultCode, loc := #caller_location) {
	if err == .ERROR || err == .CONSTRAINT || err == .MISUSE {
        text := fmt.aprintf("odin-sqlite/helpers/check_panic issued a panic! result code: %v, loc: %v", err, loc)
		panic(text)
	}
}

check_proc_args :: proc(err: sql.ResultCode, failure_proc: proc(sql.ResultCode), loc := #caller_location) {
	if err == .ERROR || err == .CONSTRAINT || err == .MISUSE {
        failure_proc(err)
	}
}

check_proc :: proc(err: sql.ResultCode, failure_proc: proc(), loc := #caller_location) {
	if err == .ERROR || err == .CONSTRAINT || err == .MISUSE {
        failure_proc()
	}
}

checK_panic_msg :: proc(err: sql.ResultCode, message: string, loc := #caller_location) {
    if err == .ERROR || err == .CONSTRAINT || err == .MISUSE {
        text := fmt.aprintf("sqlite3_helpers.check_print failed: %s\n", message)
		panic(text)
	}
}