#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "atomicfile.h"
#include "atomicdir.h"

#define NEWZ_CONST 113

typedef struct {
    atomic_file *at;
} atomic_t, *atomic_ptr;

typedef struct {
    atomic_dir *at;
} atomicdir_t, *atomicdir_ptr;

#define handle_error(self, err) \
    do { \
	if (err != ATOMIC_ERR_SUCCESS) \
	    S_handle_error(aTHX_ atomic_filename(self->at), err); \
    } while (0)

#define handle_dir_error(self, err) \
    do { \
	if (err != ATOMIC_ERR_SUCCESS) \
	    S_handle_error(aTHX_ atomic_dirname(self->at), err); \
    } while (0)

static void
S_handle_error(pTHX_ char *file, atomic_err err)
{
    char *errmsg = SvPV_nolen(get_sv("!", 1));
    switch (err) {
	case ATOMIC_ERR_SUCCESS:
	    break;
	case ATOMIC_ERR_BADCLOSE:
	    croak("error closing tempfile: %s", errmsg);
	    break;
	case ATOMIC_ERR_CANTLINK:
	    croak("error creating the backup file: %s", errmsg);
	    break;
	case ATOMIC_ERR_CANTMKDIR:
	    croak("Error creating directory '%s': %s", file, errmsg);
	    break;
	case ATOMIC_ERR_CANTMMAP:
	    croak("error creating memory map: %s", errmsg);
	    break;
	case ATOMIC_ERR_CANTREAD:
	    croak("error reading from file: %s", errmsg);
	    break;
	case ATOMIC_ERR_CANTRENAME:
	    croak("error renaming file: %s", errmsg);
	    break;
	case ATOMIC_ERR_CANTWRITE:
	    croak("error writing to temporary file: %s", errmsg);
	    break;
	case ATOMIC_ERR_COMMITBEFORETEMPFILE:
	    croak("commit_tempfile() called before tempfile()");
	    break;
	case ATOMIC_ERR_INVALIDCURRENT:
	    croak("Corrupt directory: invalid 'current' symlink: %s", file);
	    break;
	case ATOMIC_ERR_MISSINGTEMPFILE:
	    croak("tempfile disappeared before commit()");
	    break;
	case ATOMIC_ERR_NOCURRENT:
	    croak("Corrupt directory: missing 'current' symlink: %s", file);
	    break;
	case ATOMIC_ERR_NOMEM:
	    croak("Out of memory!");
	    break;
	case ATOMIC_ERR_NOTDIRECTORY:
	    croak("'%s' is not a directory", file);
	    break;
	case ATOMIC_ERR_NOTEMPFILE:
	    croak("error creating temporary file: %s", errmsg);
	    break;
	case ATOMIC_ERR_NOTOWNER:
	    croak("can't write to another user's file", errmsg);
	    break;
	case ATOMIC_ERR_OPENEDREADABLE:
	    croak("'%s' was not opened writable", file);
	    break;
	default:
	    croak("unknown error '%i'", err);
	    break;
    }
}

static int
at_scandir(void *host, char *path, int ix)
{
    dTHX;
    dSP;
    SV *cb = (SV*)host;
    I32 count;
    int retval;

    if (!cb)
	return 1;

    ENTER;
    SAVETMPS;

    PUSHMARK(SP);
    XPUSHs(sv_2mortal(newSVpv(path, 0)));
    XPUSHs(sv_2mortal(newSViv(ix)));
    PUTBACK;

    count = call_sv(cb, G_SCALAR|G_EVAL);

    SPAGAIN;
    if (count == 1)
	retval = POPi;
    else
	retval = 0;
    PUTBACK;

    FREETMPS;
    LEAVE;

    return retval;
}

MODULE = ActiveState::Dir::Atomic	PACKAGE = ActiveState::Dir::Atomic

PROTOTYPES: DISABLE

atomicdir_ptr
new(ignored, dir, ...)
	char *dir
    PREINIT:
	atomic_err	err;
	atomicdir_ptr	self;
	atomic_opts	opts;
	int i;
	int create = 0;
    CODE:
	Newz(NEWZ_CONST_INT, self, 1, atomicdir_t);

	/* Defaults */
	memset(&opts, 0, sizeof(opts));
	opts.mode = ATOMIC_READ;
	
	/* Read options */
	for (i = 2; i < items; i += 2) {
	    SV *skey = ST(i);
	    SV *sval = ST(i + 1);
	    char *key = SvPV_nolen(skey);
	    if (strEQ(key, "writable")) {
		if (SvOK(sval) && SvTRUE(sval))
		    opts.mode = ATOMIC_WRITE;
	    }
	    else if (strEQ(key, "create")) {
		if (SvIOK(sval))
		    create = (int)SvIV(sval);
	    }
	    else if (strEQ(key, "timeout")) {
		if (SvIOK(sval))
		    opts.timeout = (int)SvIV(sval);
	    }
	    else if (strEQ(key, "rotate")) {
		if (SvIOK(sval))
		    opts.rotate = (int)SvIV(sval);
	    }
	    else
		croak("Unknown option '%s'", key);
	}

	if (create) {
	    if (opts.mode == ATOMIC_WRITE)
		opts.mode = ATOMIC_CREATE;
	    else
		croak("Option create requires writable as well");
	}

	err = atomic_opendir(&self->at, dir, &opts);
	if (err != ATOMIC_ERR_SUCCESS) {
	    Safefree(self);
	    switch(err) {
		case ATOMIC_ERR_CANTOPEN:
		    croak("Can't open directory '%s': %s", dir,
			    SvPV_nolen(get_sv("!", 1)));
		    break;
		case ATOMIC_ERR_CANTLOCK:
		    croak("Can't lock directory '%s': %s", dir,
			    SvPV_nolen(get_sv("!", 1)));
		    break;
		case ATOMIC_ERR_NOTOWNER:
		    croak("Not owner of directory '%s'", dir); /* and not root */
		    break;
		case ATOMIC_ERR_NOTDIRECTORY:
		    croak("'%s' is not a directory", dir);
		    break;
		case ATOMIC_ERR_CANTMKDIR:
		    croak("Error creating '%s': %s", dir,
			    SvPV_nolen(get_sv("!", 1)));
		    break;
		case ATOMIC_ERR_NOCURRENT:
		    croak("Corrupt directory: missing 'current' symlink: %s",
			    dir);
		    break;
		case ATOMIC_ERR_INVALIDCURRENT:
		    croak("Corrupt directory: invalid 'current' symlink: %s",
			    dir);
		    break;
		default:
		    croak("Unknown error '%i': %s", err,
			    SvPV_nolen(get_sv("!", 1)));
		    break;
	    }
	}
	RETVAL = self;
    OUTPUT:
	RETVAL

void
DESTROY(self)
	atomicdir_ptr self
    CODE:
	if (self) {
	    if (self->at)
		atomic_closedir(self->at);
	    Safefree(self);
	}

void
close(self)
	atomicdir_ptr self
    CODE:
	atomic_closedir(self->at);
	self->at = NULL;

int
current(self)
	atomicdir_ptr self
    CODE:
	RETVAL = atomic_currentdir_i(self->at);
    OUTPUT:
	RETVAL

SV*
currentpath(self)
	atomicdir_ptr self
    CODE:
	RETVAL = newSVpvf("%s/%d", atomic_dirname(self->at),
				   atomic_currentdir_i(self->at));
    OUTPUT:
	RETVAL

int
scratch(self)
	atomicdir_ptr self
    CODE:
	RETVAL = atomic_scratchdir_i(self->at);
    OUTPUT:
	RETVAL

SV*
scratchpath(self)
	atomicdir_ptr self
    CODE:
	RETVAL = newSVpvf("%s/%d", atomic_dirname(self->at),
				   atomic_scratchdir_i(self->at));
    OUTPUT:
	RETVAL

void
commit(self)
	atomicdir_ptr self
    PREINIT:
	atomic_err err;
    CODE:
	err = atomic_commitdir(self->at);
	handle_dir_error(self, err);
	self->at = NULL;

void
rollback(self, idx)
	atomicdir_ptr self
	int idx
    PREINIT:
	atomic_err err;
    CODE:
	err = atomic_rollbackdir(self->at, idx);
	handle_dir_error(self, err);
	self->at = NULL;

int
scan(self, cb=NULL)
	atomicdir_ptr self
	SV* cb
    CODE:
	RETVAL = atomic_scandir(self->at, &at_scandir, cb);
    OUTPUT:
	RETVAL

MODULE = ActiveState::File::Atomic	PACKAGE = ActiveState::File::Atomic

PROTOTYPES: DISABLE

atomic_ptr
new(ignored, file, ...)
	char*	file
    PREINIT:
	atomic_err	err;
	atomic_ptr	self;
	atomic_opts	opts;
	int i;
	int create;
    CODE:
	Newz(NEWZ_CONST_INT, self, 1, atomic_t);
	memset(&opts, 0, sizeof(opts));

	/* Defaults */
	opts.mode = ATOMIC_READ;
	create = 0;

	/* Read options */
	for (i = 2; i < items; i += 2) {
	    SV *skey = ST(i);
	    SV *sval = ST(i + 1);
	    char *key = SvPV_nolen(skey);
	    if (strEQ(key, "writable")) {
		if (SvOK(sval) && SvTRUE(sval))
		    opts.mode = ATOMIC_WRITE;
	    }
	    else if (strEQ(key, "create")) {
		if (SvIOK(sval))
		    create = (int)SvIV(sval);
	    }
	    else if (strEQ(key, "nolock")) {
		if (SvIOK(sval))
		    opts.noreadlock = (int)SvIV(sval);
	    }
	    else if (strEQ(key, "timeout")) {
		if (SvIOK(sval))
		    opts.timeout = (int)SvIV(sval);
	    }
	    else if (strEQ(key, "backup_ext")) {
		if (SvPOK(sval))
		    opts.backup_ext = SvPV_nolen(sval);
	    }
	    else if (strEQ(key, "rotate")) {
		if (SvIOK(sval))
		    opts.rotate = (int)SvIV(sval);
	    }
	    else
		croak("Unknown option '%s'", key);
	}

	if (create) {
	    if (opts.mode == ATOMIC_WRITE)
		opts.mode = ATOMIC_CREATE;
	    else
		croak("Option create requires writable as well");
	}
	if (opts.noreadlock && opts.mode != ATOMIC_READ)
	    croak("Option nolock requires non-writable open mode");

	err = atomic_open(&self->at, file, &opts);
	if (err != ATOMIC_ERR_SUCCESS) {
	    Safefree(self);
	    switch(err) {
		case ATOMIC_ERR_CANTOPEN:
		    croak("Can't open file '%s': %s", file,
			    SvPV_nolen(get_sv("!", 1)));
		    break;
		case ATOMIC_ERR_CANTLOCK:
		    croak("Can't lock file '%s': %s", file,
			    SvPV_nolen(get_sv("!", 1)));
		    break;
		case ATOMIC_ERR_NOTOWNER:
		    croak("Not owner of file '%s'", file); /* and not root */
		    break;
		default:
		    croak("Unknown error '%i': %s", err,
			    SvPV_nolen(get_sv("!", 1)));
		    break;
	    }
	}
	RETVAL = self;
    OUTPUT:
	RETVAL

void
DESTROY(self)
	atomic_ptr self
    CODE:
	if (self) {
	    if (self->at)
		atomic_close(self->at);
	    Safefree(self);
	}

void
close(self)
	atomic_ptr self
    CODE:
	atomic_close(self->at);
	self->at = NULL;

SV *
slurp(self)
	atomic_ptr self
    PREINIT:
	char *buffer;
	size_t len;
	atomic_err err;
    CODE:
	err = atomic_readfile(self->at, &buffer, &len);
	handle_error(self, err);
	RETVAL = newSVpvn(buffer, (STRLEN)len);
    OUTPUT:
	RETVAL

SV *
readline(self)
	atomic_ptr self
    PREINIT:
	char *line;
	size_t len;
	atomic_err err;
    CODE:
	err = atomic_readline(self->at, &line, &len);
	handle_error(self, err);
	if (line)
	    RETVAL = newSVpvn(line, (STRLEN)len);
	else
	    RETVAL = &PL_sv_undef;
    OUTPUT:
	RETVAL

char *
_tempfile(self)
	atomic_ptr self
    PREINIT:
	char *filename;
	atomic_err err;
    CODE:
	err = atomic_tempfile(self->at, NULL, &filename);
	handle_error(self, err);
	RETVAL = filename;
    OUTPUT:
	RETVAL

void
commit_tempfile(self)
	atomic_ptr self
    PREINIT:
	atomic_err err;
    CODE:
	err = atomic_commit_tempfile(self->at);
	handle_error(self, err);
	self->at = NULL;

void
commit_string(self, str)
	atomic_ptr self
	SV *str
    PREINIT:
	atomic_err err;
	char *c_str;
	STRLEN len;
    CODE:
	c_str = SvPV(str, len);
	err = atomic_commit_string(self->at, c_str, len);
	handle_error(self, err);
	self->at = NULL;

void
commit_fd(self, fd)
	atomic_ptr self
	int fd
    PREINIT:
	atomic_err err;
    CODE:
	err = atomic_commit_fd(self->at, fd);
	handle_error(self, err);
	self->at = NULL;
