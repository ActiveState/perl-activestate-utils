#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <sys/mman.h>

#include "atomicfile.h"

extern char *my_strdup(char *);

/* Forward */
static atomic_err S_lock(int fd, int how, atomic_opts *);
static atomic_err S_save_backups(char *fname, int rfd, int rotate,
	char *backup_exit);
static void S_revert(atomic_file *self);

static atomic_opts s_default_opts = { ATOMIC_READ, NULL, 0, 0 };

atomic_err
atomic_open(atomic_file **ret, char *filename, atomic_opts *opts)
{
    int fd;
    int mode;
    int lmode;
    int save_errno;
    char *backup_ext = NULL;
    struct stat sbuf;
    int stat_failed = 0;
    atomic_err err;
    atomic_file *self;

    /* Try to malloc self */
    if (!(self = (atomic_file *)malloc(sizeof(atomic_file))))
	return ATOMIC_ERR_NOMEM;
    memset((void*)self, 0, sizeof(atomic_file));

    if (!opts)
	opts = &s_default_opts;

    if (opts->mode == ATOMIC_READ) {
	mode = O_RDONLY;
	lmode = F_RDLCK;
    }
    else {
	mode = O_RDWR;
	if (opts->mode == ATOMIC_CREATE)
	    mode |= O_CREAT;
	lmode = F_WRLCK;
    }

    /* Make sure that either we're root, or we're the owner of the file. This
     * avoids complicated error conditions where we have write permission but
     * not delete permission, so we end up failing way too late in the
     * process. The "official policy" is that we only support atomic updates
     * to a user's own files, or as root. */
    if (stat(filename, &sbuf) == 0) {
	uid_t me = geteuid();
	if (opts->mode != ATOMIC_READ && sbuf.st_uid != me && me != 0) {
	    free(self);
	    return ATOMIC_ERR_NOTOWNER;
	}
    }
    else if (opts->mode != ATOMIC_CREATE) {
	free(self);
	return ATOMIC_ERR_CANTOPEN;
    }
    else {
	stat_failed = 1;
    }

    if ((fd = open(filename, mode, 0666)) < 0) {
	free(self);
	return ATOMIC_ERR_CANTOPEN;
    }

    if (stat_failed && fstat(fd, &sbuf) != 0) {
	close(fd);
        free(self);
	return ATOMIC_ERR_CANTOPEN;
    }

    if ((err = S_lock(fd, lmode, opts)) != ATOMIC_ERR_SUCCESS) {
	save_errno = errno;
	close(fd);
	free(self);
	errno = save_errno;
	return err;
    }

    self->dest = my_strdup(filename);
    if (!self->dest) {
	free(self);
	close(fd);
	return ATOMIC_ERR_NOMEM;
    }
    self->opts = *opts;

    /* pick a backup_ext to use, then strdup() it */
    if (opts->backup_ext)
	backup_ext = opts->backup_ext;
    if (opts->rotate && !opts->backup_ext)
	backup_ext = ".";
    if (backup_ext) {
	self->opts.backup_ext = my_strdup(backup_ext);
	if (!self->opts.backup_ext) {
	    close(fd);
	    free(self->dest);
	    free(self);
	    return ATOMIC_ERR_NOMEM;
	}
    }

    /* Commit to returning successfully now. */
    self->fd_read = fd;
    self->sbuf = sbuf;
    self->fd_write = -1;
    self->temp = NULL;

    *ret = self;
    return ATOMIC_ERR_SUCCESS;
}

void
atomic_close(atomic_file *self)
{
    S_revert(self);
    if (self->dest) {
	close(self->fd_read); /* close() releases locks implicitly */
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

/* The read variants */

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
    int bufsize;
    char *temp;
    int fd;
    uid_t me;
    gid_t mygroup;
    uid_t owner;
    gid_t group;

    S_revert(self);
    if (self->opts.mode == ATOMIC_READ)
	return ATOMIC_ERR_OPENEDREADABLE;

    bufsize = strlen(self->dest) + 8;
    temp = malloc(bufsize);
    if (!temp)
	return ATOMIC_ERR_NOMEM;
    sprintf(temp, "%s.XXXXXX", self->dest);
    if ((fd = mkstemp(temp)) < 0) {
	free(temp);
	return ATOMIC_ERR_NOTEMPFILE;
    }

    /* Set the permissions to those of the original file. Attempt to set
     * the group, but don't worry if it fails. If we're root, set the
     * ownership too. */
    me = geteuid();
    mygroup = getegid();
    chmod(temp, self->sbuf.st_mode);
    owner = (self->sbuf.st_uid != me && me == 0) ? self->sbuf.st_uid : -1;
    group = (self->sbuf.st_gid != mygroup)       ? self->sbuf.st_gid : -1;
    if (owner != -1 || group != -1)
	chown(temp, owner, group);
    self->temp = temp;
    self->fd_write = fd;

    if (fdret)
	*fdret = fd;
    if (filename)
	*filename = self->temp;
    return ATOMIC_ERR_SUCCESS;
}

atomic_err
atomic_commit_tempfile(atomic_file *self)
{
    char *orig = self->dest;
    char *temp = self->temp;
    struct stat dontcare;
    atomic_err err;

    if (!temp)
	return ATOMIC_ERR_COMMITBEFORETEMPFILE;
    if (stat(temp, &dontcare) < 0) {
	S_revert(self);
	return ATOMIC_ERR_MISSINGTEMPFILE;
    }
    if (close(self->fd_write) < 0) {
	S_revert(self);
	return ATOMIC_ERR_BADCLOSE;
    }

    if ((err = S_save_backups(orig, self->fd_read, self->opts.rotate,
		    self->opts.backup_ext))
	    != ATOMIC_ERR_SUCCESS) {
	int save_errno = errno;
	S_revert(self);
	errno = save_errno;
	return err;
    }

    /* This is pretty severe -- we now have the original file, but we've
     * overwritten the last backup. It's also quite rare for rename() to fail
     * in this case, I expect. */
    if (rename(temp, orig) < 0) {
	S_revert(self);
	return ATOMIC_ERR_CANTRENAME;
    }

    /* NOTE: we *must* free self->temp here, otherwise atomic_close() will
     * call S_revert(), which will close(self->fd_write) again. That leads to
     * a race condition if another thread has used that fd in the meantime. */
    free(self->temp);
    self->temp = NULL;

    atomic_close(self);
    return ATOMIC_ERR_SUCCESS;
}

static void
S_revert(atomic_file *self)
{
    if (self->temp) {
	close(self->fd_write);
	unlink(self->temp);
	free(self->temp);
	self->temp = NULL;
    }
}

static atomic_err
S_link(char *from, int fd, char *to)
{
    unlink(to);
    if (link(from, to) < 0) {
	/* check stat before croaking, because NFS might fail falsely */
	struct stat dontcare;
	int save_errno = errno;
	if (stat(to, &dontcare) < 0) {
	    errno = save_errno;
	    return ATOMIC_ERR_CANTLINK;
	}
    }
    return ATOMIC_ERR_SUCCESS;
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
S_save_backups(char *fname, int fd, int rotate, char *backup_ext)
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
	if ((err = S_link(fname, fd, tmp1)) != ATOMIC_ERR_SUCCESS) {
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
	if ((err = S_link(fname, fd, bakname)) != ATOMIC_ERR_SUCCESS) {
	    free(bakname);
	    return err;
	}
	free(bakname);
    }
    return ATOMIC_ERR_SUCCESS;
}

static atomic_err
S_lock(int fd, int how, atomic_opts *o)
{
    struct flock l;

    /* If we're asked not to lock and we're in read mode, return */
    if (o->noreadlock && o->mode == ATOMIC_READ)
	return ATOMIC_ERR_SUCCESS;

    l.l_type = how;
    l.l_whence = 0;
    l.l_start = 0;
    l.l_len = 0; /* whole file */
    l.l_pid = 0;
    if (o->timeout) {
	int t = o->timeout;
	while (t--) {
	    if (fcntl(fd, F_SETLK, &l) < 0)
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
    return ATOMIC_ERR_CANTLOCK;
}
