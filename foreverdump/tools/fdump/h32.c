/* Exact Lua 5.1 hash32 from ForeverDump ReplayLog.lua (double arithmetic). */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>

static double hash32(const char *s, size_t n) {
    double h = 2166136261.0;
    for (size_t i = 0; i < n; i++) {
        h = h + (unsigned char)s[i];
        double a = h * 16777619.0 + fmod(h, 65521.0) * 31.0;
        h = fmod(a, 4294967296.0);
        if (h < 0) h += 4294967296.0;
    }
    return h;
}

/* lua tostring of an integer that fits in a double exactly (salt is always integer) */
static void lua_itoa(int64_t v, char *buf) {
    sprintf(buf, "%lld", (long long)v);
}

int main(int argc, char **argv) {
    if (argc < 4) {
        fprintf(stderr, "usage: h32 crack <known_id> <hex1,hex2,...> [lo hi]  OR  h32 map <salt> <ids_file>\n");
        return 2;
    }
    if (!strcmp(argv[1], "map")) {
        int64_t salt = atoll(argv[2]);
        char sb[32]; lua_itoa(salt, sb);
        FILE *f = fopen(argv[3], "r");
        if (!f) return 1;
        char line[512];
        while (fgets(line, sizeof line, f)) {
            size_t n = strlen(line);
            while (n && (line[n-1]=='\n' || line[n-1]=='\r')) line[--n] = 0;
            if (!n) continue;
            char buf[600];
            int m = snprintf(buf, sizeof buf, "%s|%s", sb, line);
            printf("%08x\t%s\n", (unsigned)hash32(buf, (size_t)m), line);
        }
        return 0;
    }
    if (!strcmp(argv[1], "crack")) {
        const char *id = argv[2];
        char hexes[256][9]; int nh = 0;
        char *p = argv[3], *q;
        while (p && *p && nh < 256) {
            q = strchr(p, ','); if (q) *q = 0;
            strncpy(hexes[nh], p, 8); hexes[nh][8]=0; nh++;
            p = q ? q+1 : NULL;
        }
        int64_t lo = argc>4 ? atoll(argv[4]) : 0;
        int64_t hi = argc>5 ? atoll(argv[5]) : 2147483647LL + 200LL*9973;
        char sb[32], buf[600];
        size_t idn = strlen(id);
        for (int64_t s = lo; s <= hi; s++) {
            lua_itoa(s, sb);
            int m = snprintf(buf, sizeof buf, "%s|%s", sb, id);
            unsigned h = (unsigned)hash32(buf, (size_t)m);
            char hx[9]; sprintf(hx, "%08x", h);
            for (int i = 0; i < nh; i++) if (!strcmp(hx, hexes[i])) {
                printf("%lld\t%s\n", (long long)s, hx);
                fflush(stdout);
            }
        }
        return 0;
    }
    return 2;
}
