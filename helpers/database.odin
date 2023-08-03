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

