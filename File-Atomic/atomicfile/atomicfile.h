/* Interface to atomically update files.
 *
 * Copyright (c) 2004, ActiveState Corporation
 * All Rights Reserved. */

#ifndef __ATOMIC_FILE_H__
#define __ATOMIC_FILE_H__

#include <sys/file.h>
#include <sys/types.h>
#include <sys/stat.h>

#include "atomictype.h"

typedef struct {
    atomic_opts opts;

    /* the original file */
    int         fd_read;
    struct stat sbuf;
    char       *dest;

    /* readblock(), readline() and readfile() internals */
    char       *nextblock;
    char       *nextline;
    char       *mbuf;

    /* the locked file; will be rename()d into place */
    int         fd_write;
    char       *lock;
    char       *temp;
} atomic_file;

/* atomic_open()
 *
 * Allocates and returns an atomic_file structure, returning a pointer to
 * it. Makes copies of 'filename' and 'opts'. The memory required for the
 * copies must be reclaimed with atomic_close().
 *
 * The 'filename' argument is the name of the file you want to open. It must
 * already exist, unless the mode is ATOMIC_CREATE. The 'opts' argument can be
 * NULL, in which case defaults are used for each option: no backup is made,
 * and the file is opened readonly.
 *
 * Calls atomic_lock() unless 'nolock' is set in 'opts'. The file remains
 * locked until either atomic_close() or atomic_commit() are called.
 *
 * Returns ATOMIC_ERR_SUCCESS if all went well, otherwise it returns
 * an error code:
 *    ATOMIC_ERR_CANTOPEN	could not open 'filename'
 *    ATOMIC_ERR_NOMEM		could not allocate memory
 *    ATOMIC_ERR_CANTLOCK	could not lock file (might have timed out)
 *
 * The caller can usually get additional error information from 'errno'.
 */
extern atomic_err
atomic_open(atomic_file **self, char *filename, atomic_opts *opts);

/* atomic_close()
 *
 * Release memory used by the structure, and the structure itself. Uncommited
 * changes are reverted, and the file is unlocked and closed. The pointer to
 * atomic_file is invalid after this call.
 */
extern void
atomic_close(atomic_file *self);

/* atomic_lock()
 *
 * Locks the file. This opens the destination file for reading, so that
 * updates made by other writers are visible to the reader methods. Both
 * readers and writers should call this if the 'nolock' option was passed to
 * atomic_open().
 *
 * Nothing should be assumed about the underlying implementation of the
 * locking (it could be fcntl/flock/link/pthread_rwlock/semaphore based,
 * depending what works best on each platform).
 */
extern atomic_err
atomic_lock(atomic_file *self);

/* atomic_read_handle()
 *
 * Returns the read file descriptor, or -1 if the file has not yet been
 * opened. When opening a file for ATOMIC_READ, atomic_open() opens the file
 * immediately. For writers, however, the file is not opened until
 * atomic_lock() is called: during atomic_open(), unless the 'nolock' option
 * is set.
 */
#define atomic_read_handle(self) ((self)->fd_read)

/* atomic_filename()
 *
 * Returns the filename passed to atomic_open().
 */
#define atomic_filename(self) ((self)->dest)

/* atomic_readblock()
 *
 * Returns a block of data from the structure. Each call to this
 * writes to the same buffer, so each call clobbers the previous
 * value. The memory is owned by the object. Lines returned may not be
 * NUL-terminated. When there are no more lines, 'line' will be
 * returned NULL.
 */
extern atomic_err
atomic_readblock(atomic_file *self, size_t blocklen, char **line, size_t *length);

/* atomic_readline()
 *
 * Returns a line from the structure. Each call to this writes to the same
 * buffer, so each call clobbers the previous value. The memory is owned by
 * the object. Lines returned may not be NUL-terminated. When there are no
 * more lines, 'line' will be returned NULL.
 */
extern atomic_err
atomic_readline(atomic_file *self, char **line, size_t *length);

/* atomic_readfile()
 *
 * Returns the entire contents of the file in a buffer. The memory is owned by
 * the object. The string may not be NUL-terminated. If the file is
 * zero-length, this returns NULL.
 */
extern atomic_err
atomic_readfile(atomic_file *self, char **buffer, size_t *length);

/* atomic_commit() variants
 *
 * Commits changes to the original file. This works by first creating a
 * temporary file and copying your changes into it (either from another file,
 * or from memory), then creating any backups (specified in atomic_open() by
 * the 'backup_ext' and 'rotate' options), then renaming the tempfile over the
 * original. This implies calling atomic_close(), so the caller should not
 * call any further methods after calling atomic_commit().
 *
 * Returns ATOMIC_ERR_SUCCESS if all went well, otherwise it returns:
 *    ATOMIC_ERR_CANTRENAME        can't rename a file[1]
 *    ATOMIC_ERR_NOMEM             can't allocate memory
 *    ATOMIC_ERR_CANTLINK          can't link (this is how backups are done)
 *
 * The caller can usually get additional error information from 'errno'.
 *
 * [1] Rotating backups (the 'rotate' option) are rotated using rename(). It
 *     is impossible to tell from the return code whether the rename()
 *     occurred while rotating backup files or while renaming the temporary
 *     file over the original, without looking at the disk. Either is
 *     considered fatal.
 */

/* Use this if you already have a filehandle open for reading.  The library
 * will read and commit the contents of the file. */
extern atomic_err
atomic_commit_fd(atomic_file *self, int fd);

/* Use this function if you have the contents of the file in a buffer. The
 * contents of the buffer will be committed. */
extern atomic_err
atomic_commit_string(atomic_file *self, char *buffer, size_t length);

/* Use these functions if you want access to the temporary file which will be
 * renamed over the original. atomic_tempfile() returns the filename and a
 * file descriptor which is opened for read and write. Calling
 * atomic_commit_tempfile() will commit the contents of the tempfile.
 *
 * DO NOT close() the fd given. DO NOT open(filename) and then close that fd.
 * Doing so may release the exclusive lock on some platforms, which means
 * waiting writers will not see the changes made by this object. */
extern atomic_err
atomic_tempfile(atomic_file *self, int *fd, char **filename);
extern atomic_err
atomic_commit_tempfile(atomic_file *self);

#endif
