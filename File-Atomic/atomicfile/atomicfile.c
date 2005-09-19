#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <sys/wait.h>

#include "atomicfile.h"

#ifndef O_LARGEFILE
#  define O_LARGEFILE 0
#endif

extern char *atomic_strdup(char *);

/* Forward */
static atomic_err S_lock(int fd, atomic_opts *);
static atomic_err S_save_backups(char *fname, int rotate, char *backup_exit);
static void S_revert(atomic_file *self);
static int S_safefd(int fd);

static atomic_opts s_default_opts = ATOMIC_OPTS_INITIALIZER;

atomic_err
atomic_open(atomic_file **ret, char *filename, atomic_opts *opts)
{
    int save_errno;
    char *backup_ext = NULL;
    atomic_err err;
    atomic_file *self;

    /* Try to malloc self. */
    if (!(self = (atomic_file *)malloc(sizeof(atomic_file))))
	return ATOMIC_ERR_NOMEM;
    memset((void*)self, 0, sizeof(atomic_file));

    if (!opts)
	opts = &s_default_opts;

    self->dest = atomic_strdup(filename);
    if (!self->dest) {
	free(self);
	return ATOMIC_ERR_NOMEM;
    }
    self->opts = *opts;

    /* pick a backup_ext to use, then strdup() it */
    if (opts->backup_ext)
	backup_ext = opts->backup_ext;
    if (opts->rotate && !opts->backup_ext)
	backup_ext = ".";
    if (backup_ext) {

	/* Ensure that backup_ext isn't "" */
	if (!strlen(backup_ext)) {
	    free(self->dest);
	    free(self);
	    return ATOMIC_ERR_EMPTYBACKUPEXT;
	}

	self->opts.backup_ext = atomic_strdup(backup_ext);
	if (!self->opts.backup_ext) {
	    free(self->dest);
	    free(self);
	    return ATOMIC_ERR_NOMEM;
	}
    }

    self->fd_read = -1;
    self->fd_write = -1;
    if (!opts->nolock) {
	if ((err = atomic_lock(self)) != ATOMIC_ERR_SUCCESS) {
	    int save_errno = errno;
	    atomic_close(self);
	    errno = save_errno;
	    return err;
	}
    }

    *ret = self;
    return ATOMIC_ERR_SUCCESS;
}

void
atomic_close(atomic_file *self)
{
    S_revert(self);
    if (self->dest) {
	if (self->fd_read != -1)
	    close(self->fd_read);
	free(self->dest);
	free(self->opts.backup_ext);
	self->dest = NULL;
    }
    if (self->mbuf) {
	munmap(self->mbuf, self->sbuf.st_size);
	self->mbuf = NULL;
    }
    free(self);
}

atomic_err
atomic_lock(atomic_file *self)
{
    atomic_err err;
    int bufsize;
    char *temp = NULL;
    char *lock = NULL;
    int tfd = -1, wfd = -1;
    uid_t me;
    gid_t mygroup;
    uid_t owner = -1;
    gid_t group = -1;
    mode_t mode = 0;
    char *basename;

    /* If we've already locked, self->fd_read is set. */
    if (self->fd_read != -1)
	return ATOMIC_ERR_SUCCESS;

    /* For readers, we can short-circuit a lot of kruft, so do it here. */
    if (self->opts.mode == ATOMIC_READ) {
	if ((self->fd_read = S_safefd(open(self->dest,
					   O_RDONLY|O_LARGEFILE))) < 0)
	{
	    return ATOMIC_ERR_CANTOPEN;
	}
	fstat(self->fd_read, &self->sbuf);
	return ATOMIC_ERR_SUCCESS;
    }

    /* Create a random dotfile in the same directory as self->dest. */
    bufsize = strlen(self->dest) + 9;
    temp = malloc(bufsize);
    if (!temp)
	return ATOMIC_ERR_NOMEM;

    basename = strrchr(self->dest, '/');
    if (basename)
	++basename;
    else
	basename = self->dest;
    /* turn it into a hidden dotfile: /foo/bar/.filename.XXXXXX */
    sprintf(temp, "%.*s.%s.XXXXXX",
	    basename - self->dest, self->dest, basename);

    /* Calculate the canonical name of the lock file. */
    bufsize -= 3;
    lock = malloc(bufsize);
    if (!lock) {
	free(temp);
	return ATOMIC_ERR_NOMEM;
    }
    /* turn it into a hidden dotfile: /foo/bar/.filename.lck */
    sprintf(lock, "%.*s.%s.lck",
	    basename - self->dest, self->dest, basename);

    if ((tfd = S_safefd(mkstemp(temp))) < 0) {
	free(temp);
	free(lock);
	return ATOMIC_ERR_NOTEMPFILE;
    }

    /* Now lock `temp'. */
    if ((err = S_lock(tfd, &self->opts)) != ATOMIC_ERR_SUCCESS)
	goto lock_failed;

    /* Attempt to acquire an exclusive lock on `lock'. */
    while (1) {
	if (link(temp, lock) == 0) {
	    /* link() success means the lock has been acquired.
	     * If we own the flock, give it up. */
	    if (wfd != -1) {
		close(wfd);
		wfd = -1; /* so we don't close it again */
	    }
	    break;
	}
	else if (errno != EEXIST) {
	    if (self->opts.debug & ATOMIC_DEBUG_TRACE)
		fprintf(stderr,
			"atomicfile: link('%s','%s') failed [%s]\n",
			temp, lock, strerror(errno));
	    err = ATOMIC_ERR_CANTLOCK;
	    goto lock_failed;
	}
	else {
	    struct stat old, new;

	    if (wfd != -1)
		close(wfd);

	    /* We must open O_RDWR because fcntl() doesn't support exclusive
	     * locks on a file open only for read. */
	    if ((wfd = S_safefd(open(lock, O_RDWR|O_LARGEFILE))) < 0) {
		if (errno != ENOENT) {
		    if (self->opts.debug & ATOMIC_DEBUG_TRACE)
			fprintf(stderr,
				"atomicfile: open('%s',O_RDWR) failed [%s]\n",
				lock, strerror(errno));
		    err = ATOMIC_ERR_CANTLOCK;
		    goto lock_failed;
		}
		continue;
	    }
	    if ((err = S_lock(wfd, &self->opts)) != ATOMIC_ERR_SUCCESS)
		goto lock_failed;

	    if (fstat(wfd, &old) == 0
	            && stat(lock, &new) == 0
		    && old.st_dev == new.st_dev
		    && old.st_ino == new.st_ino)
	    {
		/* stale lock, delete */
		if (unlink(lock) < 0) {
		    if (self->opts.debug & ATOMIC_DEBUG_TRACE)
			fprintf(stderr,
				"atomicfile: unlink('%s') failed [%s]\n",
				lock, strerror(errno));
		    err = ATOMIC_ERR_CANTLOCK;
		    goto lock_failed;
		}
	    }

	    /* We don't want to close(wfd) here, since that will wake up any
	     * other waiter which might contend with us for the link().  So
	     * wait until after the link() to do that. */
	}
    }

    /* We have an exclusive lock. */
    self->temp = temp;
    self->lock = lock;
    self->fd_write = tfd;

    me = geteuid();
    mygroup = getegid();

    if ((self->fd_read = S_safefd(open(self->dest, O_RDONLY|O_LARGEFILE))) < 0)
    {
	if (self->opts.mode != ATOMIC_CREATE) {
	    S_revert(self);
	    return ATOMIC_ERR_CANTOPEN;
	}
	mode = self->opts.cmode;
	owner = self->opts.uid;
	group = self->opts.gid;
    }
    else {
	fstat(self->fd_read, &self->sbuf);

	/* Make sure that either we're root, or we're the owner of the file.
	 * This avoids complicated error conditions where we have write
	 * permission but not delete permission, so we end up failing way too
	 * late in the process. The "official policy" is that we only support
	 * atomic updates to a user's own files, or as root. */
	if (self->sbuf.st_uid != me && me != 0) {
	    close(self->fd_read);
	    self->fd_read = -1;
	    S_revert(self);
	    return ATOMIC_ERR_NOTOWNER;
	}

	/* Set the permissions to those of the original file. Attempt to set
	 * the group, but don't worry if it fails. If we're root, set the
	 * ownership too. */
	mode = self->sbuf.st_mode;
	owner = (self->sbuf.st_uid != me && me == 0) ? self->sbuf.st_uid : -1;
	group = (self->sbuf.st_gid != mygroup)       ? self->sbuf.st_gid : -1;
    }

    if (mode)
	fchmod(self->fd_write, mode);
    if (owner != -1 || group != -1)
	fchown(self->fd_write, owner, group);

    return ATOMIC_ERR_SUCCESS;

lock_failed:
    {
	int save_errno = errno;

	/* Preconditions for getting to lock_failed:
	 *
	 * `lock' contains the name of the canonical lockfile.
	 *
	 * `temp' contains a random filename.
	 *
	 * If not -1, tfd is open(temp).
	 *
	 * If not -1, wfd is open(lock).
	 *
	 * The only time we wfd != -1 is if we couldn't unlink(lock), which is
	 * why don't bother doing it here.
	 */

	if (tfd != -1) {
	    unlink(temp);
	    close(tfd);
	}

	if (wfd != -1)
	    close(wfd);

	free(lock);
	free(temp);
	errno = save_errno;
	return err;
    }
}

/* The read variants */

atomic_err
atomic_readblock(atomic_file *self, size_t blocklen, char **lineret, size_t *lengthret)
{
    char *buffer;
    char *bufend;
    char *eol;
    size_t buflen;
    atomic_err err;

    if ((err = atomic_readfile(self, &buffer, &buflen)) != ATOMIC_ERR_SUCCESS)
	return err;
    if (buflen == 0) {
	*lineret = NULL;
	*lengthret = 0;
	return ATOMIC_ERR_SUCCESS;
    }

    if (!self->nextblock)
	self->nextblock = buffer;
    bufend = buffer + buflen;
    eol = self->nextblock;

    if (eol > bufend) {
	*lineret = NULL;
	*lengthret = 0;
    }
    else {
        eol += blocklen;
        if (eol > bufend)
          eol = bufend;

        *lineret = self->nextblock;
        *lengthret = eol - self->nextblock;
        self->nextblock = (eol == bufend) ? ++eol : eol;
    }
    return ATOMIC_ERR_SUCCESS;
}

atomic_err
atomic_readline(atomic_file *self, char **lineret, size_t *lengthret)
{
    char *buffer;
    char *bufend;
    char *eol;
    size_t buflen;
    atomic_err err;

    if ((err = atomic_readfile(self, &buffer, &buflen)) != ATOMIC_ERR_SUCCESS)
	return err;
    if (buflen == 0) {
	*lineret = NULL;
	*lengthret = 0;
	return ATOMIC_ERR_SUCCESS;
    }

    if (!self->nextline)
	self->nextline = buffer;
    bufend = buffer + buflen;
    eol = self->nextline;
    while (eol < bufend && *eol != '\n') ++eol;
    if (eol < bufend) /* i.e. *eol == '\n' */
	++eol;

    if (eol > bufend) {
	*lineret = NULL;
	*lengthret = 0;
    }
    else {
	*lineret = self->nextline;
	*lengthret = eol - self->nextline;
	self->nextline = (eol == bufend) ? ++eol : eol;
    }
    return ATOMIC_ERR_SUCCESS;
}

atomic_err
atomic_readfile(atomic_file *self, char **buffer, size_t *length)
{
    /* AIX won't let us mmap() zero bytes, so just return a static */
    if (!self->sbuf.st_size) {
	*buffer = "";
	*length = 0;
	return ATOMIC_ERR_SUCCESS;
    }
    if (!self->mbuf) {
	char *mbuf;

	if (self->fd_read == -1) {
	    errno = EINVAL;
	    return ATOMIC_ERR_CANTMMAP;
	}
	/* XXX This will not work for large files.  If the mmap fails,
	 * we should just read line by line from fd_read. */
	if ((mbuf = mmap(0, self->sbuf.st_size, PROT_READ, MAP_PRIVATE,
			self->fd_read, 0)) == MAP_FAILED)
	    return ATOMIC_ERR_CANTMMAP;
	self->mbuf = mbuf; /* store it */
    }
    *buffer = self->mbuf;
    *length = self->sbuf.st_size;
    return ATOMIC_ERR_SUCCESS;
}

/* The commit variants */

atomic_err
atomic_commit_fd(atomic_file *self, int rfd)
{
    char buffer[4096]; /* write 4K chunks */
    int n;
    int wfd;
    atomic_err err;

    /* create a temporary file */
    if ((err = atomic_tempfile(self, &wfd, NULL)) != ATOMIC_ERR_SUCCESS)
	return err;

    /* copy the contents into the tempfile */
    while (1) {
	n = read(rfd, buffer, sizeof(buffer));
	if (n < 0) {
	    S_revert(self);
	    return ATOMIC_ERR_CANTREAD;
	}
	else if (n == 0)
	    break;
	else
	    while (n) {
		int w = write(wfd, buffer, n);
		if (w < 0) {
		    S_revert(self);
		    return ATOMIC_ERR_CANTWRITE;
		}
		else
		    n -= w;
	    }
    }

    /* commit the temporary file */
    if ((err = atomic_commit_tempfile(self)) != ATOMIC_ERR_SUCCESS)
	return err;

    return ATOMIC_ERR_SUCCESS;
}

atomic_err
atomic_commit_string(atomic_file *self, char *buffer, size_t length)
{
    int wfd;
    atomic_err err;

    /* create a temporary file */
    if ((err = atomic_tempfile(self, &wfd, NULL)) != ATOMIC_ERR_SUCCESS)
	return err;

    /* write the contents into the tempfile */
    while (length) {
	int w = write(wfd, buffer, length);
	if (w < 0) {
	    S_revert(self);
	    return ATOMIC_ERR_CANTWRITE;
	}
	else {
	    length -= w;
	    buffer += w;
	}
    }

    /* commit the temporary file */
    if ((err = atomic_commit_tempfile(self)) != ATOMIC_ERR_SUCCESS)
	return err;

    return ATOMIC_ERR_SUCCESS;
}

atomic_err
atomic_tempfile(atomic_file *self, int *fdret, char **filename)
{
    if (!self->lock)
	return ATOMIC_ERR_OPENEDREADABLE;
    if (fdret)
	*fdret = self->fd_write;
    if (filename)
	*filename = self->lock;
    return ATOMIC_ERR_SUCCESS;
}

atomic_err
atomic_commit_tempfile(atomic_file *self)
{
    char *orig = self->dest;
    struct stat dontcare;
    atomic_err err;
    int i;
    int ntfd;
    char *ntmpf;

    if (!self->lock)
	return ATOMIC_ERR_COMMITBEFORETEMPFILE;
    if (stat(self->lock, &dontcare) < 0) {
	S_revert(self);
	return ATOMIC_ERR_MISSINGTEMPFILE;
    }

    if ((err = S_save_backups(orig, self->opts.rotate, self->opts.backup_ext))
	    != ATOMIC_ERR_SUCCESS)
    {
	int save_errno = errno;
	S_revert(self);
	errno = save_errno;
	return err;
    }

    ntmpf = atomic_strdup(self->temp);
    for (i = strlen(self->temp) - 6; ntmpf[i]; i++)
	ntmpf[i] = 'X';
    if ((ntfd = S_safefd(mkstemp(ntmpf))) < 0) {
	free(ntmpf);
	S_revert(self);
	return ATOMIC_ERR_NOTEMPFILE;
    }
    if ((err = S_lock(ntfd, &self->opts)) != ATOMIC_ERR_SUCCESS) {
	unlink(ntmpf);
	free(ntmpf);
	S_revert(self);
	close(ntfd);
	return err;
    }
    if (rename(ntmpf, self->lock) < 0) {
	unlink(ntmpf);
	free(ntmpf);
	S_revert(self);
	close(ntfd);
	return ATOMIC_ERR_CANTRENAME;
    }
    free(ntmpf);

    /* Check that writes to the file succeeded. This also gives up the
     * staleness-lock. There is a chance of a spurious wakeup of a single
     * waiter between the close() and the subsequent unlink(), but that will
     * be harmless (the woken up thread will find a new held-flock and go back
     * to waiting again). The write-lock itself isn't relinquished until the
     * unlink(). */
    if (close(self->fd_write) < 0) {
	S_revert(self);
	close(ntfd);
	return ATOMIC_ERR_BADCLOSE;
    }
    self->fd_write = -1;
    if (rename(self->temp, self->dest) < 0) {
	S_revert(self);
	close(ntfd);
	return ATOMIC_ERR_CANTRENAME;
    }

    /* Finally, relinquish the lock. */
    if (unlink(self->lock) < 0) {
	S_revert(self);
	close(ntfd);
	return ATOMIC_ERR_CANTUNLINK;
    }
    close(ntfd);

    /* NOTE: free self->lock here, otherwise atomic_close() will call
     * S_revert(), which will close(self->fd_write) again, and
     * unlink(self->temp). That leads to a race condition if another thread
     * has used that fd in the meantime, or if another writer has the lock. */
    free(self->lock);
    self->lock = NULL;
    free(self->temp); /* ditto for self->temp */
    self->temp = NULL;

    atomic_close(self);
    return ATOMIC_ERR_SUCCESS;
}

static void
S_revert(atomic_file *self)
{
    if (self->lock) {
	unlink(self->lock);		/* give up lock */
	if (self->fd_write != -1) {
	    close(self->fd_write);
	    self->fd_write = -1;
	}
	free(self->lock);
	self->lock = NULL;
    }
    if (self->temp) {
	unlink(self->temp);
	free(self->temp);
	self->temp = NULL;
    }
}

static atomic_err
S_link(char *from, char *to)
{
    struct stat sfrom, sto;
    int save_errno;

    unlink(to);
    if (link(from, to) == 0)
	return ATOMIC_ERR_SUCCESS;

    /* Make sure that the 'from' and 'to' files are the same file */
    save_errno = errno;
    if (stat(from, &sfrom) == 0
	    && stat(to, &sto) == 0
	    && sfrom.st_dev == sto.st_dev
	    && sfrom.st_ino == sto.st_ino)
	return ATOMIC_ERR_SUCCESS;

    errno = save_errno;
    return ATOMIC_ERR_CANTLINK;
}

static int
S_safefd(int fd)
{
#if defined(__sun__) && !defined(_LP64)
    /* stdio needs all the fds < 256 */
    if (fd >= 0 && fd < 256) {
	int newfd = fcntl(fd, F_DUPFD, 256);
	if (newfd >= 0) {
	    close(fd);
	    fd = newfd;
	}
    }
#endif
    return fd;
}

static int
S_formatted_length(int n)
{
    int i = 0;
    do {
	n /= 10;
	++i;
    } while(n);
    return i;
}

static atomic_err
S_save_backups(char *fname, int rotate, char *backup_ext)
{
    if (rotate) {
	/* calculate the maximum length required for the rotate extension. */
	int rotate_len = S_formatted_length(rotate);
	int bklen = strlen(fname)
	    + strlen(backup_ext)
	    + rotate_len
	    + 1;  /* NULL byte */
	char *tmp1, *tmp2;
	char *rot1, *rot2;
	int i;
	int top = rotate - 1;
	atomic_err err;

	tmp1 = malloc(bklen * 2); /* tmp2 just points halfway into the buf */
	if (!tmp1)
	    return ATOMIC_ERR_NOMEM;
	tmp2 = tmp1 + bklen;
	sprintf(tmp1, "%s%s", fname, backup_ext);
	strcpy(tmp2, tmp1);
	rot1 = tmp1 + bklen - rotate_len - 1;
	rot2 = tmp2 + bklen - rotate_len - 1;

	/* Walk upwards from [1, 'rotate'] looking for empty slots */
	for (i = 1; i <= rotate; ++i) {
	    struct stat dontcare;
	    sprintf(rot1, "%0*i", rotate_len, i);
	    if (stat(tmp1, &dontcare) < 0) {
		top = i - 1;
		break;
	    }
	}

	/* Walk downwards from "top" (either 'rotate' or the first empty)
	 * moving (i-1) -> i. */
	for (i = top; i >= 1; --i) {
	    sprintf(rot1, "%0*i", rotate_len, i);
	    sprintf(rot2, "%0*i", rotate_len, i + 1);
	    if (rename(tmp1, tmp2) < 0) {
		free(tmp1);
		return ATOMIC_ERR_CANTRENAME;
	    }
	}

	/* Copy the original to the first slot. */
	if ((err = S_link(fname, tmp1)) != ATOMIC_ERR_SUCCESS) {
	    free(tmp1);
	    return err;
	}
	free(tmp1);
    }
    else if (backup_ext) {
	int baklen = strlen(fname) + strlen(backup_ext) + 1;
	char *bakname = malloc(baklen);
	int prlen;
	atomic_err err;
	if (!bakname)
	    return ATOMIC_ERR_NOMEM;
	prlen = sprintf(bakname, "%s%s", fname, backup_ext);
	if ((err = S_link(fname, bakname)) != ATOMIC_ERR_SUCCESS) {
	    free(bakname);
	    return err;
	}
	free(bakname);
    }
    return ATOMIC_ERR_SUCCESS;
}

static atomic_err
S_lock(int fd, atomic_opts *o)
{
    struct flock l;

    if (o->debug & ATOMIC_DEBUG_STRICT) {
	pid_t parentpid = getpid();
	pid_t childpid;

	/* XXX need to fork because F_GETLK is useless for recursion
	 * detection within the same process. :-( */
	childpid = fork();
	if (childpid == 0) {
	    l.l_type = F_WRLCK;
	    l.l_whence = 0;
	    l.l_start = 0;
	    l.l_len = 0; /* whole file */
	    l.l_pid = 0;

	    if (fcntl(fd, F_GETLK, &l) == -1) {
		if (o->debug & ATOMIC_DEBUG_TRACE)
		    fprintf(stderr,
			    "atomicfile: fcntl(%d,F_GETLK) failed [%s]\n",
			    fd, strerror(errno));
		_exit(1);
	    }

	    /* XXX this needs a hostname or l_sysid check as well to
	     * be safe on NFS. */
	    if (l.l_type != F_UNLCK && l.l_pid == parentpid)
		_exit(2);

	    _exit(0);
	}
	else if (childpid != -1) {
	    int status;
	    if (waitpid(childpid, &status, 0) == childpid
		&& WIFEXITED(status))
	    {
		if (WEXITSTATUS(status) == 1)
		    return ATOMIC_ERR_CANTLOCK;
		if (WEXITSTATUS(status) == 2)
		    return ATOMIC_ERR_RECURSIVELOCK;
	    }
	}
	else {
	    /* this is just best effort strictness, so we don't
	     * complain if fork() fails */
	}
    }

    l.l_type = F_WRLCK;
    l.l_whence = 0;
    l.l_start = 0;
    l.l_len = 0; /* whole file */
    l.l_pid = 0;
    if (o->timeout) {
	int t = o->timeout;
	while (t--) {
	    if (fcntl(fd, F_SETLK, &l) < 0
		    && (errno == EACCES || errno == EAGAIN))
		sleep(1);
	    else
		return ATOMIC_ERR_SUCCESS;
	}
    }
    else {
	int ret;
	while ((ret = fcntl(fd, F_SETLKW, &l)) == -1 && errno == EINTR)
	    ;
	if (ret == 0)
	    return ATOMIC_ERR_SUCCESS;
    }
    if (o->debug & ATOMIC_DEBUG_TRACE)
	fprintf(stderr, "atomicfile: fcntl(%d,F_SETLK) failed [%s]\n",
		fd, strerror(errno));
    return ATOMIC_ERR_CANTLOCK;
}
