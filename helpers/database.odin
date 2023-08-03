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