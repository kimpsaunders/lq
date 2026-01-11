/*
lq symbolic link query
Copyright (C) 2026 Kim Saunders

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

#include <stdio.h>
#include <unistd.h>
#include <limits.h>
#include <string.h>
#include <errno.h>
#include <stdlib.h>
#include <stddef.h>
#include <fcntl.h>
#include <search.h>
#include <stdbool.h>
#include <assert.h>
#include <sys/types.h>
#include <sys/stat.h>
#include "devino.h"
#include "attribute.h"

#if defined(__has_include) && !defined(DISABLE_GETOPT_LONG)
  #if __has_include(<getopt.h>)
    #include <getopt.h>
    #define GETOPT_LONG
  #endif
#endif

#ifndef ATTRIBUTES_SIZE
#define ATTRIBUTES_SIZE 16
#endif

#ifndef DEVINOS_SIZE
#define DEVINOS_SIZE 64
#endif

/* number of elements in the array */
#define SIZE(a) ( (sizeof a) / (sizeof 0[a]) )
/* pointer _beyond_ the last element in the array - only values *less* than this can be dereferenced */
#define END(a)   ( a + SIZE(a) )

/* write a nul byte at the character pointed to, and return the old value */
static char terminate(char *dst) {
  char value = *dst;
  *dst = '\0';
  return value;
}

/* restore a value at the char pointed to */
static char restore(char *dst, const char value) {
  return *dst = value;
}

char *delimiter = "/";
int verbose = 0;
int expand = 0;

#ifdef GETOPT_LONG
  #define PUNCT ", --"
  #define VERBOSE    "verbose"
  #define HELP       "help"
  #define DELIMITER  "delimiter"
  #define ATTRIBUTES "attributes"
  #define EXPAND     "expand"
  #define VERSION    "version"
  #define VERBOSE2    PUNCT  VERBOSE "       "
  #define HELP2       PUNCT  HELP "          "
  #define DELIMITER2  PUNCT  DELIMITER "     "
  #define ATTRIBUTES2 PUNCT  ATTRIBUTES "    "
  #define EXPAND2     PUNCT  EXPAND "        "
  #define VERSION2    "  --" VERSION "       "
  #define HELPFLAG    "--" HELP
  #define getopt_function       getopt_long
  #define getopt_long_arguments , long_options, &option_index
  struct option long_options[] = {
    { VERBOSE,    no_argument,       NULL, 'v'},
    { HELP,       no_argument,       NULL, 'h'},
    { VERSION,    no_argument,       NULL, 'V'},
    { EXPAND,     no_argument,       NULL, 'e'},
    { DELIMITER,  required_argument, NULL, 'd'},
    { ATTRIBUTES, required_argument, NULL, 'a'},
    { 0,          0,                 0,     0}
  };
#else
  #define BLANK "  "
  #define VERBOSE2    BLANK
  #define HELP2       BLANK
  #define DELIMITER2  BLANK
  #define ATTRIBUTES2 BLANK
  #define EXPAND2     BLANK
  #define HELPFLAG    "-h"
  #define getopt_function getopt
  #define getopt_long_arguments
#endif

int usage(const char *self) {
  printf("Usage: %s [OPTION]... SYMLINK...\n"
         "Recursively expand SYMLINK(s), to standard output.\n\n"
	 "  -a" ATTRIBUTES2 "attribute(s) to capture\n"
	 "  -d" DELIMITER2  "delimiter for attribute output\n"
	 "  -e" EXPAND2     "expand symbolic links\n"
	 "  -v" VERBOSE2    "verbose error messages\n"
	 "  -h" HELP2       "show help\n"
#ifdef GETOPT_LONG
	 "    " VERSION2    "output version information and exit\n"
#endif
	 ,
	 self
  );
  return EXIT_SUCCESS;
}

int version(const char *self) {
  printf("%s 0.01\n"
         "Copyright (C) 2026 Kim Saunders\n", self);
  return EXIT_SUCCESS;
}

int error_too_many_attributes(const char *self, int limit, const char *attribute) {
  fprintf(stderr, "%s: Too many attributes, only %d allowed: %s\n", self, limit, attribute);
  return 1;
}

int error_too_many_levels(const char *self, int limit, const char *path) {
  fprintf(stderr, "%s: %s, only %d allowed: %s\n", self, strerror(ELOOP), limit, path);
  return 1;
}

int error_try_help(const char *self) {
  fprintf(stderr, "Try '%s " HELPFLAG "' for more information.\n", self);
  return EXIT_FAILURE;
}

int error_missing_operand(const char *self) {
  fprintf(stderr, "%s: missing operand\n", self);
  return error_try_help(self);
}

int error_path_error(const char *self, const char *path, int error) {
  fprintf(stderr, "%s: %s: %s\n", self, path, strerror(error));
  return EXIT_FAILURE;
}

char *split(const char *self, char *path, struct attribute *attr, struct attribute *attr_end) {
  for (char *slash; (slash = strchr(path, '/'));) {
    /* the / *must* be after the first character... */
    if (slash > path) {
      terminate(slash);
      attr->name = path;
      if (++attr == attr_end) return path;
    }
    path = slash + 1;
  }

  if (*path) {
    attr->name = path;
    if (++attr == attr_end) return path;
  }

  attr->name = NULL;
  return NULL;
}

static struct attribute *capture(struct attribute *attr, char *value) {
  if (attr) {
    attr->value = value;
    attr->length = strlen(value);
  }
  return NULL;
}

int query(const char *self, int indent, char *path, struct devino *devinos, struct devino *devinos_end, struct attribute *attributes, struct attribute *attributes_end) {
  /* first path element identified following any leading directories */
  char *name = path, *dirend = NULL, *rest = NULL;

  /* slash found at the end of leading directories / before the first non-directory path element */
  struct attribute *pending = NULL;
  struct stat st = {0};


  /* look for leading directories at the start of path */
  for (char *slash; (slash = strchr(name, '/'));) {
    while (slash > path && slash[1] == '/') slash++;

    char *term = slash;
    if (slash == path) term++;
    char c = terminate(term);

    if (lstat(path, &st) < 0) return error_path_error(self, path, errno);

    if (S_ISDIR(st.st_mode)) {
      dirend = term;
    }
    else if (S_ISLNK(st.st_mode)) {
      rest = slash + 1;
      break;
    }
    else {
      return error_path_error(self, path, ENOTDIR);
    }

    pending = capture(pending, name);

    /* it was a directory, reset back to 0 */
    st.st_ino = 0;

    for (struct attribute *attribute = attributes; attribute < attributes_end && attribute->name; attribute++){
      if (strcmp(name, attribute->name)) continue;
      pending = attribute;
      break;
    }

    /* restore the slash back where it was */
    restore(term, c);
    name = slash + 1;
  }

  capture(pending, name);

  /* change directory */
  if (dirend) {
    char c = terminate(dirend);
    if (chdir(path)) return error_path_error(self, path, errno);
    restore(dirend, c);
  }
  
  /* stat name (within leading directory) if needed... */
  if (st.st_ino) {}
  else if (lstat(name, &st) < 0) {
    if (verbose) fprintf(stderr, "%s: %s: %s\n", self, path, strerror(errno));
    return EXIT_FAILURE;
  }

  if (S_ISLNK(st.st_mode)) {
    /* search for an existing, seen instance of the st_dev / st_ino pair (indicating a loop) */
    if (bsearch(&st, devinos, devinos_end - devinos, sizeof *devinos, devinocmp)) {
      printf("%*s...\n", indent * 2, "");
      return ELOOP;
    }

    /* not a loop, so we need to add add this st_dev / st_ino pair. the array is sorted, so... */
    if (devinos->st_ino) return error_too_many_levels(self, DEVINOS_SIZE, name);
    memcpy(devinos, &st, sizeof *devinos);
    qsort(devinos, devinos_end - devinos, sizeof *devinos, devinocmp);

    char target[PATH_MAX] = {0};
    ssize_t len;
    if ((len = readlink(name, target, sizeof target)) < 0) return error_path_error(self, path, errno);

    if (expand) printf("%*s%s -> %s\n", indent++ * 2, "", path, target);
  
    /* there is more path after this symbolic link to append */
    if (rest && *rest) snprintf(target + len, (sizeof target) - len, "/%s", rest);
    
    return query(self, indent, target, devinos, devinos_end, attributes, attributes_end);
  }

  if (expand) printf("%*s%s\n", indent * 2, "", path);

  if (rest) {
    fprintf(stderr, "%s: Not a directory (%s)\n", path, rest);
    return -1;
  }

  indent++;
  for (struct attribute *attr = attributes; attr < attributes_end && attr->name; attr++) {
    if (!attr->value) continue;
    printf("%*s%s%s%*.*s\n", indent * 2, "", attr->name, delimiter, attr->length, attr->length, attr->value);
    attr->value = NULL;
  }

  return 0;
}

int main(int argc, char *argv[]) {
  
  char name[] = __FILE__;
  struct attribute attributes[ATTRIBUTES_SIZE] = {{.name=NULL}};
  char *self;

  if (argc && *argv) self = *argv;
  else 
  {
    name[(sizeof name) - 3] = '\0';
    self = name;
  }

  for (int opt, option_index; (opt = getopt_function(argc, argv, "heva:d:" getopt_long_arguments)) != -1;)
  {
    char *supernumary;
    switch (opt) {
      case 'a':
	if ((supernumary = split(self, optarg, attributes, END(attributes)))) return error_too_many_attributes(self, ATTRIBUTES_SIZE - 1, supernumary);
	break;
      case 'e':
        expand = true;
        break;
      case 'd':
	delimiter = optarg;
	break;
      case 'h': return usage(self);
      case 'v':
        verbose = true;
	break;
      case 'V': return version(self);
      case '?': return error_try_help(self);
      default:
	assert(false);
	return EXIT_FAILURE;
    }
  }

  if (optind >= argc) return error_missing_operand(self);

  if (!attributes->name) expand = true;

  /* open & store the original current dirctory */
  const int dot = open(".", O_DIRECTORY);
  if (dot < 0) {
    fprintf(stderr, "%s: Unable to open directory: %s\n", self, strerror(errno));
    return EXIT_FAILURE;
  }

  int status = EXIT_SUCCESS;

  for (int i = optind; i < argc; i++) {
    /* initialized array, all members, including st_ino are 0 */
    struct devino devinos[DEVINOS_SIZE] = {0};
    if (!expand) printf("%s\n", argv[i]);

    const int error = query(self, 0, argv[i], devinos,  END(devinos), attributes, END(attributes));
    if (error) status = error;

    /* move back to the original current directory before moving onto the next argument */
    if (fchdir(dot)) return error_path_error(self, ".", errno);
  }

  return status;
}
