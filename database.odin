package sqlite3

import "core:fmt"
import "core:strings"
import "core:runtime"
import "core:reflect"
import "core:mem"

Database :: struct {
	connection: ^Conn,
	cache: map[string]^Stmt,
}

make_database :: proc(name: string) -> (db: ^Database, err: ResultCode) {
	db = new(Database)
	cname := strings.clone_to_cstring(name)
	err = open(cname, &db.connection) 
    return
}