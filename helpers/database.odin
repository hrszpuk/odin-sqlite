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

prepare :: proc(db: ^Database, cmd: string) -> (stmt: ^sql.Stmt, err: sql.ResultCode) {
	if existing_stmt := db.cache[cmd]; existing_stmt != nil {
		stmt = existing_stmt
	} else {
		data := strings.clone_to_cstring(cmd)
		sql.prepare_v2(db.connection, data, i32(len(cmd)), &stmt, nil); 
		db.cache[cmd] = stmt
	}

	return
}

destroy_cache :: proc(db: ^Database) {
	for key, value in db.cache {
		sql.finalize(value)
	}
}

// data from the struct has to match wanted column names
// changes the cmd string to the arg which should be a struct
select :: proc(cmd_end: string, struct_arg: any, args: ..any) -> (err: ResultCode) {
	b := strings.builder_make_len_cap(0, 128)
	defer strings.builder_destroy(&b)

	strings.write_string(&b, "SELECT ")

	ti := runtime.type_info_base(type_info_of(struct_arg.id))
	struct_info := ti.variant.(runtime.Type_Info_Struct)
	for name, i in struct_info.names {
		strings.write_string(&b, name)

		if i != len(struct_info.names) - 1 {
			strings.write_byte(&b, ',')
		} else {
			strings.write_byte(&b, ' ')
		}
	}

	strings.write_string(&b, cmd_end)

	full_cmd := strings.to_string(b)
	stmt := db_cache_prepare(full_cmd) or_return
	db_bind(stmt, ..args) or_return

	for {
		result := step(stmt)

		if result == .DONE {
			break
		} else if result != .ROW {
			return result
		}

		// get column data per struct field
		for i in 0..<len(struct_info.names) {
			type := struct_info.types[i].id
			offset := struct_info.offsets[i]
			struct_value := any { rawptr(uintptr(struct_arg.data) + offset), type }
			db_any_column(stmt, i32(i), struct_value) or_return
		}
	}

	return
}


_any_column :: proc(stmt: ^Stmt, column_index: i32, arg: any) -> (err: ResultCode) {
	ti := runtime.type_info_base(type_info_of(arg.id))
	#partial switch info in ti.variant {
		case runtime.Type_Info_Integer: {
			value := column_int(stmt, column_index)
			// TODO proper i64

			switch arg.id {
				case i8: (cast(^i8) arg.data)^ = i8(value)
				case i16: (cast(^i16) arg.data)^ = i16(value)
				case i32: (cast(^i32) arg.data)^ = value
				case i64: (cast(^i64) arg.data)^ = i64(value)
			}
		}	

		case runtime.Type_Info_Float: {
			value := column_double(stmt, column_index)

			switch arg.id {
				case f32: (cast(^f32) arg.data)^ = f32(value)
				case f64: (cast(^f64) arg.data)^ = value
			}			
		}

		case runtime.Type_Info_String: {
			value := column_text(stmt, column_index)

			switch arg.id {
				case string: {
					(cast(^string) arg.data)^ = strings.clone(
						string(value), 
						context.temp_allocator,
					)
				}

				case cstring: {
					(cast(^cstring) arg.data)^ = strings.clone_to_cstring(
						string(value), 
						context.temp_allocator,
					)
				}
			}
		}
	}

	return
}


// auto insert INSERT INTO cmd_names VALUES (...)
insert :: proc(cmd_names: string, args: ..any) -> (err: ResultCode) {
	b := strings.builder_make_len_cap(0, 128)
	defer strings.builder_destroy(&b)

	strings.write_string(&b, "INSERT INTO ")
	strings.write_string(&b, cmd_names)
	strings.write_string(&b, " VALUES ")

	strings.write_byte(&b, '(')
	for arg, i in args {
			fmt.sbprintf(&b, "?%d", i + 1)

		if i != len(args) - 1 {
			strings.write_byte(&b, ',')
		}
	}
	strings.write_byte(&b, ')')

	full_cmd := strings.to_string(b)

	stmt := db_cache_prepare(full_cmd) or_return
	db_bind(stmt, ..args) or_return
	db_bind_run(stmt) or_return
	return
}