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

typedef struct {
    atomic_file_mode mode;      /* whether to open read or read/write */
    char *backup_ext;           /* what extension to append to backups */
    int rotate;                 /* how many backups to keep */
    int timeout;                /* how long (secs) to wait for lock */
    int noreadlock;             /* if set, don't lock on read */
#if 0
    char *lockfile;             /* lock this file, rather than the original */
#endif
} atomic_opts;

typedef enum {
    ATOMIC_ERR_SUCCESS=0,
    ATOMIC_ERR_BADCLOSE,
    ATOMIC_ERR_CANTOPEN,
    ATOMIC_ERR_CANTLINK,
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
    ATOMIC_ERR__LAST_ /* in case the C compiler can't handle trailing ',' */
} atomic_err;

#endif
