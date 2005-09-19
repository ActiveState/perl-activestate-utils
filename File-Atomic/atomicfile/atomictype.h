/* Common code for atomic file and atomic directories.
 *
 * Copyright (C) 2003, ActiveState Corporation
 * All Rights Reserved */
#ifndef __ATOMIC_TYPE_H__
#define __ATOMIC_TYPE_H__

typedef enum {
    ATOMIC_READ = 0,
    ATOMIC_WRITE,
    ATOMIC_CREATE
} atomic_file_mode;

typedef enum {		/* bit flags */
    ATOMIC_DEBUG_NONE	= 0x00,
    ATOMIC_DEBUG_STRICT	= 0x01,
    ATOMIC_DEBUG_TRACE	= 0x02
} atomic_debug_flags;			

typedef struct {
    atomic_file_mode mode;      /* whether to open read or read/write */
    char *backup_ext;           /* what extension to append to backups */
    int rotate;                 /* how many backups to keep */
    int timeout;                /* how long (secs) to wait for lock */
    int nolock;                 /* if set, atomic_open() doesn't lock */
    uid_t uid;			/* user for newly created files */
    gid_t gid;			/* group for newly created files */
    mode_t cmode;		/* creat() mode for new files */
    atomic_debug_flags debug;	/* additional debug flags */
} atomic_opts;

#define ATOMIC_OPTS_INITIALIZER \
	{ ATOMIC_READ, NULL, 0, 0, 0, (uid_t)-1, (gid_t)-1, (mode_t)0, 0 }

typedef enum {
    ATOMIC_ERR_SUCCESS=0,
    ATOMIC_ERR_BADCLOSE,
    ATOMIC_ERR_CANTOPEN,
    ATOMIC_ERR_CANTLINK,
    ATOMIC_ERR_CANTUNLINK,
    ATOMIC_ERR_CANTLOCK,
    ATOMIC_ERR_CANTMMAP,
    ATOMIC_ERR_CANTREAD,
    ATOMIC_ERR_CANTRENAME,
    ATOMIC_ERR_CANTWRITE,
    ATOMIC_ERR_COMMITBEFORETEMPFILE,
    ATOMIC_ERR_MISSINGTEMPFILE,
    ATOMIC_ERR_NOMEM,
    ATOMIC_ERR_NOTEMPFILE,
    ATOMIC_ERR_NOTOWNER,
    ATOMIC_ERR_OPENEDREADABLE,
    ATOMIC_ERR_NOTDIRECTORY,
    ATOMIC_ERR_CANTMKDIR,
    ATOMIC_ERR_NOCURRENT,
    ATOMIC_ERR_INVALIDCURRENT,
    ATOMIC_ERR_UNINITIALISED,
    ATOMIC_ERR_PATHTOOLONG,
    ATOMIC_ERR_RECURSIVELOCK,
    ATOMIC_ERR_EMPTYBACKUPEXT,
    ATOMIC_ERR__LAST_ /* in case the C compiler can't handle trailing ',' */
} atomic_err;

#endif
