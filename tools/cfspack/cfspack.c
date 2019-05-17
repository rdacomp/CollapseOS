#include <stdio.h>
#include <dirent.h>
#include <string.h>

#define BLKSIZE 0x100
#define HEADERSIZE 0x20
#define MAX_FN_LEN 25   // 26 - null char
#define MAX_FILE_SIZE (BLKSIZE * 0x100) - HEADERSIZE

int spitblock(char *fullpath, char *fn)
{
    FILE *fp = fopen(fullpath, "r");
    fseek(fp, 0, SEEK_END);
    long fsize = ftell(fp);
    if (fsize > MAX_FILE_SIZE) {
        fclose(fp);
        fprintf(stderr, "File too big: %s %ld\n", fullpath, fsize);
        return 1;
    }
    /* Compute block count.
     * We always have at least one, which contains 0x100 bytes - 0x20, which is
     * metadata. The rest of the blocks have a steady 0x100.
     */
    unsigned char blockcount = 1;
    int fsize2 = fsize - (BLKSIZE - HEADERSIZE);
    if (fsize2 > 0) {
        blockcount += (fsize2 / BLKSIZE);
    }
    if (blockcount * BLKSIZE < fsize + HEADERSIZE) {
        blockcount++;
    }
    putchar('C');
    putchar('F');
    putchar('S');
    putchar(blockcount);
    // file size is little endian
    putchar(fsize & 0xff);
    putchar((fsize >> 8) & 0xff);
    int fnlen = strlen(fn);
    for (int i=0; i<MAX_FN_LEN; i++) {
        if (i < fnlen) {
            putchar(fn[i]);
        } else {
            putchar(0);
        }
    }
    // And the last FN char which is always null
    putchar(0);
    char buf[MAX_FILE_SIZE] = {0};
    rewind(fp);
    fread(buf, fsize, 1, fp);
    fclose(fp);
    fwrite(buf, (blockcount * BLKSIZE) - HEADERSIZE, 1, stdout);
    fflush(stdout);
    return 0;
}

int spitdir(char *path, char *prefix)
{
    DIR *dp;
    struct dirent *ep;

    int prefixlen = strlen(prefix);
    dp = opendir(path);
    if (dp == NULL) {
        fprintf(stderr, "Couldn't open directory.\n");
        return 1;
    }
    while (ep = readdir(dp)) {
        if ((strcmp(ep->d_name, ".") == 0) || strcmp(ep->d_name, "..") == 0) {
            continue;
        }
        if (ep->d_type != DT_DIR && ep->d_type != DT_REG) {
            fprintf(stderr, "Only regular file or directories are supported\n");
            return 1;
        }
        int slen = strlen(ep->d_name);
        if (prefixlen + slen> MAX_FN_LEN) {
            fprintf(stderr, "Filename too long: %s/%s\n", prefix, ep->d_name);
            return 1;
        }
        char fullpath[0x1000];
        strcpy(fullpath, path);
        strcat(fullpath, "/");
        strcat(fullpath, ep->d_name);
        char newprefix[MAX_FN_LEN];
        strcpy(newprefix, prefix);
        if (prefixlen > 0) {
            strcat(newprefix, "/");
        }
        strcat(newprefix, ep->d_name);
        if (ep->d_type == DT_DIR) {
            int r = spitdir(fullpath, newprefix);
            if (r != 0) {
                return r;
            }
        } else {
            int r = spitblock(fullpath, newprefix);
            if (r != 0) {
                return r;
            }
        }
    }
    closedir(dp);
    return 0;
}

int main(int argc, char *argv[])
{
    if (argc != 2) {
        fprintf(stderr, "Usage: cfspack /path/to/dir\n");
        return 1;
    }
    char *srcpath = argv[1];
    return spitdir(srcpath, "");
}

