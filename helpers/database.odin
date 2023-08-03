package sqlite3_helpers

import "core:fmt"
import "core:strings"
import "core:runtime"
import "core:reflect"
import "core:mem"
import sql ".."

Database :: struct {
	connection: ^sql.Conn,
	cache: map[string]^sql.Stmt,
}

make_db :: proc(name: string) -> (db: ^Database, err: sql.ResultCode) {
	db = new(Database)
	cname := strings.clone_to_cstring(name)
	err = sql.open(cname, &db.connection) 
    delete(cname)
    return
}

destroy_db :: proc(db: ^Database) -> (err: sql.ResultCode) {
    err = sql.close(db.connection)
    check(err, "failed to close database")
    delete(db.cache)
    free(db)
    return
}

exec :: proc{
    exec_cache,
    exec_no_cache,
}

exec_no_cache :: proc(db: ^Database, cmd: string) -> (err: sql.ResultCode) {
	data := strings.clone_to_cstring(cmd)
	stmt: ^sql.Stmt
	sql.prepare_v2(db.connection, data, i32(len(cmd)), &stmt, nil) or_return
	//db_run(stmt) or_return
	//finalize(stmt) or_return
	return
}

exec_cache :: proc(db: ^Database, cmd: string, args: ..any) -> (err: sql.ResultCode) {
    //stmt := db_cache_prepare(cmd) or_return
	//db_bind(stmt, ..args) or_return
	//db_bind_run(stmt) or_return
    return
}

run :: proc(stmt: ^sql.Stmt) -> (err: sql.ResultCode) {
	for {
		result := sql.step(stmt)

		if result == .DONE {
			break
		} else if result != .ROW {
			return result
		}
	}

	return
}


bind_run :: proc(stmt: ^sql.Stmt) -> (err: sql.ResultCode) {
	run(stmt) or_return
	sql.reset(stmt) or_return
	sql.clear_bindings(stmt) or_return
	return
}

bind :: proc(stmt: ^sql.Stmt, args: ..any) -> (err: sql.ResultCode) {
	for arg, index in args {
		index := index + 1
		ti := runtime.type_info_base(type_info_of(arg.id))

		if arg == nil {
			sql.bind_null(stmt, i32(index)) or_return
			continue
		}

		if arg.id == []byte {
			slice := cast(^mem.Raw_Slice) arg.data
			sql.bind_blob(
				stmt, 
				i32(index), 
				cast(^u8) arg.data, 
				i32(slice.len), 
				sql.STATIC,
			) or_return
			continue
		}

		#partial switch info in ti.variant {
			case runtime.Type_Info_Integer: {
				value, valid := reflect.as_i64(arg)
				
				if valid {
					sql.bind_int(stmt, i32(index), i32(value)) or_return
				} else {
					return .ERROR
				}
			}

			case runtime.Type_Info_Float: {
				value, valid := reflect.as_f64(arg)
				if valid {
					sql.bind_double(stmt, i32(index), f64(value)) or_return
				} else {
					return .ERROR					
				}
			}

			case runtime.Type_Info_String: {
				text, valid := reflect.as_string(arg)
				
				if valid {
					data := strings.clone_to_cstring(text)
					sql.bind_text(stmt, i32(index), data, i32(len(text)), sql.STATIC) or_return
				} else {
					return .ERROR
				}
			}
		}
	}
	return
}


set_cache_cap :: proc(db: ^Database, cap: int) {
	db.cache = make(map[string]^sql.Stmt, cap)		
}

destroy_cache :: proc(db: ^Database) {
	for key, value in db.cache {
		sql.finalize(value)
	}
}