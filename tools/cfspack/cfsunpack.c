#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <sys/stat.h>

#define BLKSIZE 0x100
#define HEADERSIZE 0x20
#define MAX_FN_LEN 25   // 26 - null char

bool ensuredir(char *path)
{
    char *s = path;
    while (*s != '\0') {
        if (*s == '/') {
            *s = '\0';
            struct stat path_stat;
            if (stat(path, &path_stat) != 0) {
                if (mkdir(path, S_IRWXU | S_IRWXG | S_IROTH | S_IXOTH) != 0) {
                    return false;
                }
            }
            *s = '/';
        }
        s++;
    }
    return true;
}

bool unpackblk(char *dstpath)
{
    char buf[MAX_FN_LEN+1];
    if (fgets(buf, 3+1, stdin) == NULL) {
        return false;
    }
    if (strcmp(buf, "CFS") != 0) {
        return false;
    }
    int c = getchar();
    uint8_t blkcnt = c;
    if (blkcnt == 0) {
        return false;
    }
    c = getchar();
    uint16_t fsize = c & 0xff;
    c = getchar();
    fsize |= (c & 0xff) << 8;

    if (fgets(buf, MAX_FN_LEN+1+1, stdin) == NULL) {
        return false;
    }
    char fullpath[0x1000];
    strcpy(fullpath, dstpath);
    strcat(fullpath, "/");
    strcat(fullpath, buf);
    if (!ensuredir(fullpath)) {
        return false;
    }
    int blksize = (BLKSIZE-HEADERSIZE)+(BLKSIZE*(blkcnt-1));
    int skipcount = blksize - fsize;
    FILE *fp = fopen(fullpath, "w");
    while (fsize) {
        c = getchar();
        if (c == EOF) {
            return false;
        }
        fputc(c, fp);
        fsize--;
    }
    fclose(fp);
    while (skipcount) {
        getchar();
        skipcount--;
    }
    return true;
}

int main(int argc, char *argv[])
{
    if (argc != 2) {
        fprintf(stderr, "Usage: cfspack /path/to/dest\n");
        return 1;
    }
    char *dstpath = argv[1];
    // we fail if there isn't at least one block
    if (!unpackblk(dstpath)) {
        return 1;
    }
    while (unpackblk(dstpath));
    return 0;
}


