#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>

#include "atomicdir.h"

#ifndef PATH_MAX
#define PATH_MAX 1024
#endif

extern char *atomic_strdup(char *);

static atomic_err
lock(atomic_file **l, char *root, atomic_opts *opts)
{
    char path[PATH_MAX];
    int r = snprintf(path, sizeof(path), "%s/.lock", root);
    if (r < 0 || r >= sizeof(path))
	return ATOMIC_ERR_PATHTOOLONG;
    if (opts->mode == ATOMIC_READ) {
	struct stat sbuf;
	if (stat(path, &sbuf) != 0)
	    return ATOMIC_ERR_UNINITIALISED;
	return ATOMIC_ERR_SUCCESS;
    }
    return atomic_open(l, path, opts);
}

/* Create the root directory and the rotation subdirectories. Does not attempt
 * to delete all the directories on error. */
static atomic_err
subdirs(char *root, int *num_dirs, atomic_opts *opts)
{
    atomic_err err;
    atomic_file *af;
    char path[PATH_MAX];
    char *line;
    size_t llen;
    int i;

    /* If 'root/.top' exists, read it and set *rotate. Otherwise, write the
     * value *rotate into it. */

    i = snprintf(path, sizeof(path), "%s/.top", root);
    if (i < 0 || i >= sizeof(path))
	return ATOMIC_ERR_PATHTOOLONG;

    if ((err = atomic_open(&af, path, opts)) != ATOMIC_ERR_SUCCESS)
	return err;
    if ((err = atomic_readline(af, &line, &llen)) != ATOMIC_ERR_SUCCESS) {
	atomic_close(af);
	return err;
    }

    if (llen) {
	/* read the line and calculate how many bytes are there */
	int ndirs = 0;
	for (; isdigit(*line); line++, llen--) {
	    ndirs *= 10;
	    ndirs += *line - '0';
	}
	if (llen && !strchr("\r\n", *line)) {
	    atomic_close(af);
	    return ATOMIC_ERR_INVALIDCURRENT; /* invalid data */
	}

	atomic_close(af);
	*num_dirs = ndirs;
    }
    else if (opts->mode == ATOMIC_READ) {
	atomic_close(af);
	return ATOMIC_ERR_UNINITIALISED;
    }
    else {
	int sz = snprintf(path, sizeof(path), "%d\n", *num_dirs);
	if (sz < 0 || sz >= sizeof(path)) {
	    atomic_close(af);
	    return ATOMIC_ERR_PATHTOOLONG;
	}
	if ((err = atomic_commit_string(af, path, sz)) != ATOMIC_ERR_SUCCESS) {
	    atomic_close(af);
	    return err;
	}
	for (i = 1; i <= *num_dirs; i++) {
	    sz = snprintf(path, sizeof(path), "%s/%d", root, i);
	    if (sz < 0 || sz >= sizeof(path)) {
		atomic_close(af);
		return ATOMIC_ERR_PATHTOOLONG;
	    }
	    if (mkdir(path, 0777) < 0 && errno != EEXIST)
		return ATOMIC_ERR_CANTMKDIR;
	}
    }
    return ATOMIC_ERR_SUCCESS;
}

static int
current(atomic_dir *self)
{
    char lbuf[128]; /* huge! */
    int sz;
    int current;

    if ((sz = readlink(self->current, lbuf, sizeof(lbuf))) < 0)
	return 0;
    else if (sz >= sizeof(lbuf))
	return 0;
    lbuf[sz] = '\0'; /* readlink doesn't add a NUL */
    sscanf(lbuf, "%d", &current);
    return current;
}

atomic_err
atomic_opendir(atomic_dir **ret, char *root, atomic_opts *useropts)
{
    struct stat sbuf;
    char path[PATH_MAX];
    int me = geteuid();
    int ndirs;
    int r;
    atomic_err err;
    atomic_file *lk = NULL;
    atomic_dir *self;
    atomic_opts opts = ATOMIC_OPTS_INITIALIZER;

    if (!(self = (atomic_dir *)malloc(sizeof(atomic_dir))))
	return ATOMIC_ERR_NOMEM;
    memset((void *)self, 0, sizeof(atomic_dir));

    if (useropts) {
	opts = *useropts;
	opts.backup_ext = NULL;
	opts.nolock = 0; /* we MUST lock for writing */
    }
    if (opts.rotate < 3)
	opts.rotate = 3;
    ndirs = opts.rotate;
    opts.rotate = 0;

    /* If they specified ATOMIC_CREATE, create everything.
     * Otherwise, make sure:
     *
     *  1. $root exists and is a directory
     *  2. $root/.lock exists and is a file
     *  3. $root/current exists and is a symlink (or file on Windows)
     *  4. $root/current points to a subdirectory
     */
    if (stat(root, &sbuf) == 0) {
	if (!S_ISDIR(sbuf.st_mode)) {
	    free(self);
	    return ATOMIC_ERR_NOTDIRECTORY;
	}
	else if (opts.mode != ATOMIC_READ && sbuf.st_uid != me && me != 0) {
	    free(self);
	    return ATOMIC_ERR_NOTOWNER;
	}
    }
    else if (opts.mode != ATOMIC_CREATE) {
	free(self);
	return ATOMIC_ERR_CANTOPEN;
    }
    else if (mkdir(root, 0777) < 0) {
	free(self);
	return ATOMIC_ERR_CANTMKDIR;
    }

    /* This reports errors if the directory existed but the lock file did not,
     * and ATOMIC_CREATE wasn't used. */
    if ((err = lock(&lk, root, &opts)) != ATOMIC_ERR_SUCCESS) {
	free(self);
	return err;
    }

    /* Create the subdirectories (ignores errors if they exist). This sets the
     * ndirs parameter to either opts.rotate if created the directories, or
     * the number of directories initialized in 'root' when it was created. */
    if ((err = subdirs(root, &ndirs, &opts)) != ATOMIC_ERR_SUCCESS) {
	if (lk)
	    atomic_close(lk);
	free(self);
	return err;
    }

    /* Set up 'self' */
    self->root = atomic_strdup(root);
    if (!self->root) {
	if (lk)
	    atomic_close(lk);
	free(self);
	return ATOMIC_ERR_NOMEM;
    }
    r = snprintf(path, sizeof(path), "%s/current", self->root);
    if (r < 0 || r >= sizeof(path)) {
	if (lk)
	    atomic_close(lk);
	free(self->root);
	free(self);
	return ATOMIC_ERR_PATHTOOLONG;
    }
    self->current = atomic_strdup(path);
    if (!self->current) {
	if (lk)
	    atomic_close(lk);
	free(self->root);
	free(self);
	return ATOMIC_ERR_NOMEM;
    }

    self->opts = opts;
    self->lock = lk;
    self->topdir = ndirs;

    /* Load the symlink if it exists, but don't create one if it doesn't
     * exist. Creating one would imply that there is valid contents in the
     * directory, which wouldn't be true since nobody ever committed it. */
    if (!current(self) && opts.mode != ATOMIC_CREATE) {
	atomic_closedir(self);
	return ATOMIC_ERR_NOCURRENT;
    }

    *ret = self;
    return ATOMIC_ERR_SUCCESS;
}

void
atomic_closedir(atomic_dir *self)
{
    if (self->lock) {
	if (self->opts.mode == ATOMIC_READ)
	    atomic_close(self->lock);
	else
	    atomic_commit_string(self->lock, "", 0);
    }
    free(self->current);
    free(self->root);
    free(self);
}

atomic_err
atomic_currentdir(atomic_dir *self, char *name, size_t len)
{
    int cur = current(self);
    int r = snprintf(name, len, "%s/%d", self->root, cur);
    if (r < 0 || r >= len)
	return ATOMIC_ERR_PATHTOOLONG;
    return ATOMIC_ERR_SUCCESS;
}

int
atomic_currentdir_i(atomic_dir *self)
{
    return current(self);
}

#define VERSION_SYMLINK "atomic_version"

#define VERSION_STR_SIZE (ATOMIC_VERSION_MAX_LEN - 1) /* leave room for NUL */

static int
version(char *path, char *version_str) {
    int sz;
    if ((sz = readlink(path, version_str, VERSION_STR_SIZE)) < 0)
	return 0;
    else if (sz > VERSION_STR_SIZE)
	sz = VERSION_STR_SIZE;
    version_str[sz] = '\0'; /* readlink doesn't add a NUL */
    return sz;    
}

int
atomic_version(atomic_dir *self, const char* dir, char *version_str)
{
    char path[PATH_MAX];
    int r = snprintf(path, sizeof(path), "%s/%s", dir, VERSION_SYMLINK);
    if (r < 0 || r >= sizeof(path))
	return ATOMIC_ERR_PATHTOOLONG;
    return version(path, version_str);
}

int
atomic_version_i(atomic_dir *self, int dir, char *version_str)
{
    char path[PATH_MAX];
    int r = snprintf(path, sizeof(path), "%s/%d/%s", self->root, dir,
		     VERSION_SYMLINK);
    if (r < 0 || r >= sizeof(path))
	return ATOMIC_ERR_PATHTOOLONG;
    return version(path, version_str);
}

#define NEXTDIR(self) (current(self) % (self)->topdir + 1)

atomic_err
atomic_scratchdir(atomic_dir *self, char *name, size_t len)
{
    int scratch;
    int r;
    if (self->opts.mode == ATOMIC_READ)
	return ATOMIC_ERR_OPENEDREADABLE;
    scratch = NEXTDIR(self);
    r = snprintf(name, len, "%s/%d", self->root, scratch);
    if (r < 0 || r >= len)
	return ATOMIC_ERR_PATHTOOLONG;
    return ATOMIC_ERR_SUCCESS;
}

int
atomic_scratchdir_i(atomic_dir *self)
{
    return NEXTDIR(self);
}

static atomic_err
rollback(atomic_dir *self, int ix)
{
    char tmp[PATH_MAX];
    char lbuf[128];
    int r;
    if (self->opts.mode == ATOMIC_READ)
	return ATOMIC_ERR_OPENEDREADABLE;
    r = snprintf(tmp, sizeof(tmp), "%s/current.XXXXXX", self->root);
    if (r < 0 || r >= sizeof(tmp))
	return ATOMIC_ERR_PATHTOOLONG;
    r = snprintf(lbuf, sizeof(lbuf), "%d", ix);
    if (r < 0 || r >= sizeof(lbuf))
	return ATOMIC_ERR_NOMEM;
    mktemp(tmp);
    if (symlink(lbuf, tmp) < 0)
	return ATOMIC_ERR_CANTLINK;
    if (rename(tmp, self->current) < 0)
	return ATOMIC_ERR_CANTRENAME;
    atomic_closedir(self);
    return ATOMIC_ERR_SUCCESS;
}

atomic_err
atomic_commitdir(atomic_dir *self)
{
    return atomic_commitdir_version(self, NULL);
}

atomic_err
atomic_commitdir_version(atomic_dir *self, const char *version)
{
    char tmp[PATH_MAX];
    int ix = NEXTDIR(self);
    int r = snprintf(tmp, sizeof(tmp), "%s/%d/%s", self->root, ix,
		     VERSION_SYMLINK);
    if (r < 0 || r >= sizeof(tmp))
	return ATOMIC_ERR_PATHTOOLONG;
    (void)unlink(tmp);
    if (version && symlink(version, tmp) < 0)
	return ATOMIC_ERR_CANTLINK;
    return rollback(self, ix);
}

atomic_err
atomic_rollbackdir(atomic_dir *self, int ix)
{
    return rollback(self,ix);
}

int
atomic_scandir(atomic_dir *self,
	       int (*cb)(void *host, char *path, int ix),
	       void *host)
{
    int count = 0;
    int top = self->topdir;
    int i;
    if (!cb)
	return self->topdir;
    for (i = current(self); top; top--, i = i % self->topdir + 1) {
	char path[PATH_MAX];
	int r = snprintf(path, sizeof(path), "%s/%d", self->root, i);
	if (r < 0 || r >= sizeof(path)) {
	    /* XXX no way to return error? */
	    break;
	}
	++count;
	if (!cb(host, path, i))
	    break;
    }
    return count;
}
