/* Interface to atomically update directories.
 *
 * Copyright (c) 2003, ActiveState Corporation
 * All Rights Reserved. */

#ifndef __ATOMIC_DIR_H__
#define __ATOMIC_DIR_H__

#include "atomicfile.h"

/* NOTE:
 *
 * ActiveState's atomic_opendir() enforces a specific directory structure to
 * ensure atomicity:
 *
 *    ROOT                  - the directory passed to atomic_opendir()
 *    ROOT/.lock            - a lock file used to prevent collisions
 *    ROOT/.top             - a file containing the maximum number of
 *                            directories supported by this directory.
 *    ROOT/current          - a symlink containing the current directory
 *    ROOT/1
 *    ROOT/2
 *    ROOT/3
 *    ROOT/...              - the data itself is stored in a numbered
 *                            subdirectory. The current set of data is always
 *                            referenced by the 'current' symlink.
 *
 * If the directory is opened readonly, no locking occurs. The object will
 * read the 'current' symlink and use the resultant directory. Subsequent
 * updates will not be "seen" through this object, until the number of updates
 * has "rolled over".
 *
 * If the directory is opened for writing, the ".lock" file is opened and
 * locked, and the next directory is opened for writing. Any changes will
 * happen in the 'next' directory.
 */

typedef struct {
    atomic_opts opts;
    char *root;             /* original directory */
    char *current;          /* "$root/current" */
    atomic_file *lock;      /* "$root/.lock" */
    int topdir;             /* the top directory, or max subdirs */
} atomic_dir;

/* atomic_opendir()
 *
 * Allocates and returns an atomic_dir structure, returning a pointer to it.
 * Makes copies of 'dirname' and 'opts'. The memory required for the copies
 * must be reclaimed with atomic_closedir().
 *
 * Notes about the options struct:
 *  - the 'backup_ext' option is always ignored.
 *  - the 'noreadlock' option is always true.
 *  - the 'rotate' option is ignored unless 'mode' is ATOMIC_CREATE and the
 *    directory doesn't exist. In this case it is used to determine how many
 *    subdirectories to create. Once created, the directory is
 *    self-describing, and 'rotate' is ignored.
 */
extern atomic_err
atomic_opendir(atomic_dir **self, char *dirname, atomic_opts *opts);

/* atomic_closedir()
 *
 * Releases memory used by the structure, and the structure itself.
 * The directory itself is closed and unlocked, and the 'current' symlink is
 * not updated.
 */
extern void
atomic_closedir(atomic_dir *self);

/* atomic_dirname()
 *
 * The name passed to atomic_open()
 */
#define atomic_dirname(self) ((self)->root)

/* atomic_currentdir()
 * atomic_currentdir_i()
 *
 * Returns the name of the 'current' directory. This can be used by
 * applications to periodically check whether the atomic directory has been
 * updated. Because the current directory cycles through a circular set of
 * directories, updates are not seen by running applications. The _i variant
 * returns the integer representation of the current directory.
 *
 * Each time you call this, the `current` symlink is dereferenced, to ensure
 * that changes made by other programs are picked up. In write mode, this
 * file will never change, since no other program may modify `current` while
 * the lock is held.
 *
 * Readers should call this once and remember the value returned for
 * use in all the operations that need to see a consistent "view" of
 * the data.
 *
 * Returns ATOMIC_ERR_NOMEM if the buffer is too small.
 */
extern atomic_err
atomic_currentdir(atomic_dir *self, char *name, size_t sz);
extern int
atomic_currentdir_i(atomic_dir *self);

/* atomic_version()
 * atomic_version_i()  
 *
 * Get the version associated with the data in a particular directory.
 * Interally this dereferences a symlink called "version" in the
 * specified directory.
 *
 * The input to atomic_version and atomic_version_i should be the same
 * format as the output of atomic_currentdir or atomic_currentdir_i,
 * respectively.
 *
 * The buffer given must be at least ATOMIC_VERSION_MAX_LEN long.
 *
 * Returns the length of the version string, not including the trailing NUL.
 * Returns 0 if there is no version.
 */

#define ATOMIC_VERSION_MAX_LEN 255

extern int
atomic_version(atomic_dir *self, const char* dir, char *version);
extern int
atomic_version_i(atomic_dir *self, int dir, char *version);


/* atomic_scratchdir()
 * atomic_scratchdir_i()
 *
 * Returns the name of the directory that will be committed when
 * atomic_commitdir() is called. Applications should make all changes in this
 * directory. This will be one of the numbered subdirectories. The _i variant
 * returns the integer representation of the scratchdir().
 *
 * In readonly mode, this always returns NULL. The _i variant returns zero.
 */
extern atomic_err
atomic_scratchdir(atomic_dir *self, char *name, size_t sz);
extern int
atomic_scratchdir_i(atomic_dir *self);

/* atomic_commitdir()
 * atomic_commitdir_version()  
 *
 * Commits changes made to the scratch directory returned by
 * atomic_scratchdir(). All locks are released, and 'current' is updated. This
 * implies calling atomic_closedir(), so the caller should not call any
 * further methods after calling atomic_commitdir().
 *
 * atomic_commitdir_version is the same as atomic_commitdir except that it
 * allows you to associate a version string with the data in the directory.
 * The version will be stored in a symlink with the name ATOMIC_VERSION_SYMLINK
 * in the data directory.  The version string will be truncated at
 * ATOMIC_VERSION_MAX_LEN characters.
 */
extern atomic_err
atomic_commitdir(atomic_dir *self);
extern atomic_err
atomic_commitdir_version(atomic_dir *self, const char *version);


/* atomic_rollbackdir()
 *
 * Sets the current directory to the specified index. All locks are released
 * and 'current' is updated. This implies calling atomic_closedir(), so the
 * caller should not call any further methods after calling atomic_rollback().
 */
extern atomic_err
atomic_rollbackdir(atomic_dir *self, int ix);

/* atomic_scandir()
 *
 * Invokes the callback 'cb' for each backup directory. Stops if the callback
 * returns false or when all directories have been scanned. Scanning starts at
 * the currently-active directory.
 * XXX The API here seems broken--they is no way to return error.
 */
extern int
atomic_scandir(atomic_dir *self,
	       int (*cb)(void *host, char *path, int ix),
	       void *host);

#endif
