package sqlite3

import "core:c"
import "core:os"

when ODIN_OS == .Windows {
	foreign import sqlite 	"sqlite3.lib" 

} else when ODIN_OS == .Linux {
	foreign import sqlite 	"sqlite3.a"
	foreign import 			"system:pthread"
	foreign import 			"system:dl"

} else when ODIN_OS == .Darwin {
	foreign import sqlite 	"sqlite3.o" 
} 

callback :: proc "c" (data: rawptr, a: c.int, b: [^]cstring, c: [^]cstring) -> ResultCode

@(default_calling_convention="c", link_prefix="sqlite3_")
foreign sqlite {
	libversion 			:: proc()                                    	-> cstring ---

	open 				:: proc(filename: cstring, db: ^^Conn) 			-> ResultCode ---
	close 				:: proc(db: ^Conn) 								-> ResultCode ---
	
	exec 				:: proc(db: ^Conn, sql: cstring, call: callback, arg: rawptr, errmsg: ^cstring) 							-> ResultCode ---
	prepare_v2 			:: proc(db: ^Conn, sql: cstring, nbytes: c.int, satement: ^^Stmt, tail: ^cstring) 							-> ResultCode ---
	prepare_v3  		:: proc(db: ^Conn, sql: cstring, nbytes : c.int, flags: PrepareFlag, statement: ^^Stmt, tail: ^cstring) 	-> ResultCode ---
	
	step 				:: proc(stmt: ^Stmt) 							-> ResultCode ---
	finalize 			:: proc(stmt: ^Stmt) 							-> ResultCode ---

	last_insert_rowid 	:: proc(db: ^Conn) 					-> i64 ---
	
	column_name 		:: proc(stmt: ^Stmt, i_col: c.int) 	-> cstring ---
	column_blob 		:: proc(stmt: ^Stmt, i_col: c.int) 	-> ^byte ---
	column_text 		:: proc(stmt: ^Stmt, i_col: c.int) 	-> cstring ---
	column_bytes 		:: proc(stmt: ^Stmt, i_col: c.int) 	-> c.int ---
	
	column_int 			:: proc(stmt: ^Stmt, i_col: c.int) 	-> c.int ---
	column_double 		:: proc(stmt: ^Stmt, i_col: c.int) 	-> c.double ---
	column_type 		:: proc(stmt: ^Stmt, i_col: c.int) 	-> c.int ---
	
	errcode 			:: proc(db: ^Conn) -> c.int ---
	extended_errcode 	:: proc(db: ^Conn) -> c.int ---
	errmsg 				:: proc(db: ^Conn) -> cstring ---

	reset 				:: proc(stmt: ^Stmt) -> ResultCode ---
	clear_bindings 		:: proc(stmt: ^Stmt) -> ResultCode ---

	bind_int 			:: proc(stmt: ^Stmt, index: c.int, value: c.int) -> ResultCode ---
	bind_null 			:: proc(stmt: ^Stmt, index: c.int) -> ResultCode ---
	bind_int64 			:: proc(stmt: ^Stmt, index: c.int, value: i64) -> ResultCode ---
	bind_double 		:: proc(stmt: ^Stmt, index: c.int, value: c.double) -> ResultCode ---

	bind_text :: proc(
		stmt: ^Stmt, 
		index: c.int, 
		first: cstring, 
		byte_count: c.int, 
		lifetime: uintptr,
		// lifetime: proc "c" (data: rawptr),
	) -> ResultCode ---

	bind_blob :: proc(
		stmt: ^Stmt,
		index: c.int,
		first: ^byte,
		byte_count: c.int,
		lifetime: uintptr,
	) -> ResultCode ---

	trace_v2 :: proc(
		db: ^Conn, 
		mask: TraceFlags,
		call: proc "c" (mask: TraceFlag, x, y, z: rawptr) -> c.int,
		ctx: rawptr,
	) -> ResultCode ---

	sql :: proc(stmt: ^Stmt) -> cstring ---
	expanded_sql :: proc(stmt: ^Stmt) -> cstring ---
}

STATIC :: uintptr(0)
TRANSIENT :: ~uintptr(0)

TraceFlag :: enum u8 {
	STMT 	= 0x01,
	PROFILE = 0x02,
	ROW 	= 0x04,
	CLOSE 	= 0x08,
}
TraceFlags :: bit_set[TraceFlag]

LIMIT_LENGTH 				:: 0
LIMIT_SQL_LENGTH 			:: 1
LIMIT_COLUMN 				:: 2
LIMIT_EXPR_DEPTH 			:: 3
LIMIT_COMPOUND_SELECT 		:: 4
LIMIT_VDBE_OP 				:: 5
LIMIT_FUNCTION_ARG 			:: 6
LIMIT_ATTACHED 				:: 7
LIMIT_LIKE_PATTERN_LENGTH 	:: 8
LIMIT_VARIABLE_NUMBER 		:: 9
LIMIT_TRIGGER_DEPTH 		:: 10
LIMIT_WORKER_THREADS 		:: 11
N_LIMIT 					:: LIMIT_WORKER_THREADS + 1

// seems to be only a HANDLE
Stmt :: struct {}

Vfs 	:: struct {}
Vdbe 	:: struct {}
CollSeq :: struct {}
Mutex 	:: struct {}
Db 		:: struct {}
Pgno 	:: struct {}

Conn :: struct {
	pVfs: ^Vfs,           			/* OS Interface */
  	pVdbe: ^Vdbe,          			/* List of active virtual machines */
 	pDfltColl: ^CollSeq,        	/* BINARY collseq for the database encoding */

  	mutex: ^Mutex,         			/* Connection mutex */

  	aDb: ^Db,                       /* All backends */
  	nDb: c.int,                     /* Number of backends currently in use */
  	mDbFlags: u32,                 	/* flags recording c.internal state */

  	flags: u64,                    	/* flags settable by pragmas. See below */
  	lastRowid: i64,                	/* ROWID of most recent insert (see above) */
  	szMmap: i64,                   	/* Default mmap_size setting */
  	nSchemaLock: u32,              	/* Do not reset the schema when non-zero */
  	openFlags: c.uint,       		/* Flags passed to sqlite3_vfs.xOpen() */

  	errCode: c.int,                 /* Most recent error code (SQLITE_*) */
  	errMask: c.int,                 /* & result codes with this before returning */

  	iSysErrno: c.int,               /* Errno value from last system error */
  	dbOptFlags: u32,               	/* Flags to enable/disable optimizations */
  	enc: u8,                       	/* Text encoding */
  	autoCommit: u8,                	/* The auto-commit flag. */
  	temp_store: u8,                	/* 1: file 2: memory 0: default */
  	mallocFailed: u8,              	/* True if we have seen a malloc failure */
  	bBenignMalloc: u8,             	/* Do not require OOMs if true */
  	dfltLockMode: u8,              	/* Default locking-mode for attached dbs */
  	nextAutovac: c.char,      		/* Autovac setting after VACUUM if >=0 */
  	suppressErr: u8,               	/* Do not issue error messages if true */
  	vtabOnConflict: u8,            	/* Value to return for s3_vtab_on_conflict() */
  	isTransactionSavepoint: u8,    	/* True if the outermost savepoc.int is a TS */
  	mTrace: u8,                    	/* zero or more SQLITE_TRACE flags */
  	noSharedCache: u8,             	/* True if no shared-cache backends */
  	nSqlExec: u8,                  	/* Number of pending OP_SqlExec opcodes */
  	nextPagesize: c.int,            /* Pagesize after VACUUM if >0 */
  	magic: u32,                    	/* Magic number for detect library misuse */
  	nChange: c.int,                 /* Value returned by sqlite3_changes() */
  	nTotalChange: c.int,            /* Value returned by sqlite3_total_changes() */
  	aLimit: [N_LIMIT]c.int,   		/* Limits */
  	nMaxSorterMmap: c.int,          /* Maximum size of regions mapped by sorter */

  	init: struct {      			/* Information used during initialization */
    	newTnum: Pgno,              /* Rootpage of table being initialized */
    	iDb: u8,                    /* Which db file is being initialized */
    	busy: u8,                   /* TRUE if currently initializing */
    	orphanTrigger: u8, 			/* Last statement is orphaned TEMP trigger */
    	imposterTable: u8, 			/* Building an imposter table */
    	reopenMemdb: u8,   			/* ATTACH is really a reopen using MemDB */
    	azInit: ^^u8,               /* "type", "name", and "tbl_name" columns */
  	},

  	nVdbeActive: c.int,             /* Number of VDBEs currently running */
  	nVdbeRead: c.int,               /* Number of active VDBEs that read or write */
 	nVdbeWrite: c.int,              /* Number of active VDBEs that read and write */
  	nVdbeExec: c.int,               /* Number of nested calls to VdbeExec() */
  	nVDestroy: c.int,               /* Number of active OP_VDestroy operations */

  	nExtension: c.int,              /* Number of loaded extensions */
 	aExtension: ^^rawptr,          /* Array of shared library handles */
}

PrepareFlag :: enum c.int {
    // Prepared statment hint that the statement is likely to be retained for a
    // long time and probably re-used many times. Without this flag,
    // sqlite3_prepare_v3/sqlite3_prepare16_v3 assume that the prepared statement
    // will be used just once or at most a few times and then destroyed (finalize).
    // The current implementation acts on this by avoiding use of lookaside memory.
    PERSISTENT = 0x01,
    // No-op, do not use
    NORMALIZE  = 0x02,
    // Prepared statement flag that causes the SQL compiler to return an error
    // if the statement uses any virtual tables.
    NO_VTAB    = 0x04,
}

ResultCode :: enum c.int {
	OK 			= 0,   	/* Successful result */
	ERROR 		= 1,   	/* Generic error */
	INTERNAL 	= 2,   	/* Internal logic error in SQLite */
	PERM 		= 3,   	/* Access permission denied */
	ABORT 		= 4,   	/* Callback routine requested an abort */
	BUSY 		= 5,   	/* The database file is locked */
	LOCKED 		= 6,   	/* A table in the database is locked */
	NOMEM 		= 7,   	/* A malloc() failed */
	READONLY 	= 8,   	/* Attempt to write a readonly database */
	INTERRUPT 	= 9,   	/* Operation terminated by sqlite3_interrupt()*/
	IOERR 		= 10,   /* Some kind of disk I/O error occurred */
	CORRUPT 	= 11,   /* The database disk image is malformed */
	NOTFOUND 	= 12,   /* Unknown opcode in sqlite3_file_control() */
	FULL 		= 13,   /* Insertion failed because database is full */
	CANTOPEN 	= 14,   /* Unable to open the database file */
	PROTOCOL 	= 15,   /* Database lock protocol error */
	EMPTY 		= 16,   /* Internal use only */
	SCHEMA 		= 17,   /* The database schema changed */
	TOOBIG 		= 18,   /* String or BLOB exceeds size limit */
	CONSTRAINT 	= 19,   /* Abort due to constraint violation */
	MISMATCH 	= 20,   /* Data type mismatch */
	MISUSE 		= 21,   /* Library used incorrectly */
	NOLFS 		= 22,   /* Uses OS features not supported on host */
	AUTH 		= 23,   /* Authorization denied */
	FORMAT 		= 24,   /* Not used */
	RANGE 		= 25,   /* 2nd parameter to sqlite3_bind out of range */
	NOTADB 		= 26,   /* File opened that is not a database file */
	NOTICE 		= 27,   /* Notifications from sqlite3_log() */
	WARNING 	= 28,   /* Warnings from sqlite3_log() */
	ROW 		= 100,  /* sqlite3_step() has another row ready */
	DONE 		= 101,  /* sqlite3_step() has finished executing */
}
