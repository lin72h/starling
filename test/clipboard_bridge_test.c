// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * Unit tests for the clipboard bridge's bounded pipe I/O — the part that keeps
 * a slow or wedged peer from turning a paste into a hang. No compositor, no
 * GPU, no display: just pipes, so this runs in the fast tier.
 *
 * The source is #included rather than linked because the functions under test
 * are static, and they should stay static — they are not API.
 *
 * WLCLIP_TIMEOUT_MS is overridden on the command line so the deadline cases
 * cost milliseconds instead of two seconds each.
 */

/* Before ANY header: the bridge needs pipe2, and its own _GNU_SOURCE define
 * comes too late once this file has already pulled in unistd.h. */
#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#include <assert.h>
#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#include "../sdk/Sources/WaylandClipboardBridge/wayland_clipboard_client.c"

static int failures = 0;

#define CHECK(cond, ...)                                          \
    do {                                                          \
        if (!(cond)) {                                            \
            printf("  FAIL %s:%d: ", __func__, __LINE__);         \
            printf(__VA_ARGS__);                                  \
            printf("\n");                                         \
            failures++;                                           \
        }                                                         \
    } while (0)

static double ms_since(struct timespec t0) {
    struct timespec t1;
    clock_gettime(CLOCK_MONOTONIC, &t1);
    return (t1.tv_sec - t0.tv_sec) * 1e3 + (t1.tv_nsec - t0.tv_nsec) / 1e6;
}

/* ---------------------------------------------------------------- reading -- */

static void test_read_gets_everything(void) {
    int fds[2];
    assert(pipe(fds) == 0);
    const char* msg = "clipboard payload";
    assert(write(fds[1], msg, strlen(msg)) == (ssize_t)strlen(msg));
    close(fds[1]);                       /* EOF: the owner is done */

    size_t len = 0;
    char* got = read_all_bounded(fds[0], &len);   /* takes ownership of fds[0] */
    CHECK(got != NULL, "returned NULL");
    CHECK(len == strlen(msg), "len %zu, want %zu", len, strlen(msg));
    CHECK(got && strcmp(got, msg) == 0, "got %s", got ? got : "(null)");
    free(got);
}

static void* write_slowly(void* arg) {
    int fd = *(int*)arg;
    for (int i = 0; i < 4; i++) {
        ssize_t n = write(fd, "chunk", 5);
        (void)n;
        struct timespec t = {0, 5 * 1000 * 1000};   /* 5ms */
        nanosleep(&t, NULL);
    }
    close(fd);
    return NULL;
}

static void test_read_reassembles_chunks(void) {
    int fds[2];
    assert(pipe(fds) == 0);
    pthread_t th;
    pthread_create(&th, NULL, write_slowly, &fds[1]);

    size_t len = 0;
    char* got = read_all_bounded(fds[0], &len);
    pthread_join(th, NULL);
    CHECK(len == 20, "len %zu, want 20 (4 chunks of 5)", len);
    CHECK(got && strcmp(got, "chunkchunkchunkchunk") == 0,
          "got %s", got ? got : "(null)");
    free(got);
}

static void test_read_is_bounded_when_owner_never_writes(void) {
    /* The frozen-owner case: a peer that holds the pipe open and never writes
     * must yield an empty paste on a deadline, not a hang. */
    int fds[2];
    assert(pipe(fds) == 0);
    struct timespec t0;
    clock_gettime(CLOCK_MONOTONIC, &t0);

    size_t len = 0;
    char* got = read_all_bounded(fds[0], &len);
    double took = ms_since(t0);

    CHECK(len == 0, "len %zu, want 0", len);
    CHECK(got != NULL && got[0] == '\0', "expected an empty string");
    CHECK(took >= WLCLIP_TIMEOUT_MS * 0.5,
          "returned in %.0fms — did not wait for the deadline", took);
    CHECK(took < WLCLIP_TIMEOUT_MS * 6,
          "took %.0fms, deadline is %dms", took, WLCLIP_TIMEOUT_MS);
    free(got);
    close(fds[1]);
}

/* Trickles a byte at a time for well past the deadline, then stops.
 *
 * Bounded on purpose. An unbounded dribbler makes the buggy build HANG rather
 * than fail, and a test that hangs stalls the tier instead of reporting — the
 * failure has to be legible, not just present. */
static void* dribble_past_the_deadline(void* arg) {
    int fd = *(int*)arg;
    int iterations = (WLCLIP_TIMEOUT_MS * 10) / 2;   /* ~10x the deadline */
    for (int i = 0; i < iterations; i++) {
        if (write(fd, "x", 1) != 1) break;
        struct timespec t = {0, 2 * 1000 * 1000};    /* 2ms */
        nanosleep(&t, NULL);
    }
    close(fd);
    return NULL;
}

static void test_read_deadline_is_per_transfer_not_per_poll(void) {
    /* The bug this guards: the deadline used to be handed to each poll() call,
     * so a peer trickling a byte at a time reset it forever and the read never
     * ended. It must bound the WHOLE transfer. */
    int fds[2];
    assert(pipe(fds) == 0);
    pthread_t th;
    pthread_create(&th, NULL, dribble_past_the_deadline, &fds[1]);

    struct timespec t0;
    clock_gettime(CLOCK_MONOTONIC, &t0);
    size_t len = 0;
    char* got = read_all_bounded(fds[0], &len);
    double took = ms_since(t0);

    CHECK(took < WLCLIP_TIMEOUT_MS * 6,
          "a trickling peer held the read for %.0fms (deadline %dms)",
          took, WLCLIP_TIMEOUT_MS);
    free(got);
    pthread_join(th, NULL);
}

/* ---------------------------------------------------------------- writing -- */

struct drain_arg { int fd; size_t total; };

static void* drain(void* arg) {
    struct drain_arg* d = arg;
    char buf[4096];
    for (;;) {
        ssize_t n = read(d->fd, buf, sizeof(buf));
        if (n <= 0) break;
        d->total += (size_t)n;
    }
    close(d->fd);
    return NULL;
}

static void test_write_delivers_everything(void) {
    int fds[2];
    assert(pipe(fds) == 0);
    struct drain_arg d = {.fd = fds[0], .total = 0};
    pthread_t th;
    pthread_create(&th, NULL, drain, &d);

    size_t big = 512 * 1024;             /* well past one pipe buffer */
    char* payload = malloc(big);
    memset(payload, 'a', big);
    write_all_bounded(fds[1], payload, big);   /* takes ownership of fds[1] */
    pthread_join(th, NULL);

    CHECK(d.total == big, "peer read %zu bytes, want %zu", d.total, big);
    free(payload);
}

static void test_write_is_bounded_when_peer_never_reads(void) {
    /* A client that asks to paste and then does not read must not wedge the
     * bridge thread: the write is abandoned on the deadline. */
    int fds[2];
    assert(pipe(fds) == 0);
    size_t big = 8 * 1024 * 1024;        /* far larger than any pipe buffer */
    char* payload = malloc(big);
    memset(payload, 'b', big);

    struct timespec t0;
    clock_gettime(CLOCK_MONOTONIC, &t0);
    write_all_bounded(fds[1], payload, big);
    double took = ms_since(t0);

    CHECK(took < WLCLIP_TIMEOUT_MS * 6,
          "write to a stalled peer took %.0fms (deadline %dms)",
          took, WLCLIP_TIMEOUT_MS);
    free(payload);
    close(fds[0]);
}

/* ------------------------------------------------------------ mime ranking -- */

static void test_mime_preference_order(void) {
    CHECK(mime_rank("text/plain;charset=utf-8") > mime_rank("text/plain"),
          "utf-8 should outrank bare text/plain");
    CHECK(mime_rank("text/plain") > mime_rank("UTF8_STRING"),
          "text/plain should outrank UTF8_STRING");
    CHECK(mime_rank("UTF8_STRING") > mime_rank("STRING"),
          "UTF8_STRING should outrank STRING");
    CHECK(mime_rank("text/html") > 0, "text/* should rank above nothing");
    CHECK(mime_rank("image/png") == 0, "image/png is not text");
    CHECK(mime_rank("application/octet-stream") == 0, "binary is not text");
}

int main(void) {
    /* The helper threads deliberately keep writing after the reader has gone,
     * which is the situation these bounds exist for. Without this the test
     * process is killed by SIGPIPE before it can report anything — which is
     * how the bridge's own missing SIGPIPE handling was found. */
    signal(SIGPIPE, SIG_IGN);
    printf("clipboard bridge (timeout %dms)\n", WLCLIP_TIMEOUT_MS);
    test_read_gets_everything();
    test_read_reassembles_chunks();
    test_read_is_bounded_when_owner_never_writes();
    test_read_deadline_is_per_transfer_not_per_poll();
    test_write_delivers_everything();
    test_write_is_bounded_when_peer_never_reads();
    test_mime_preference_order();

    if (failures) {
        printf("FAILED — %d check(s)\n", failures);
        return 1;
    }
    printf("  7 tests passed\n");
    return 0;
}
