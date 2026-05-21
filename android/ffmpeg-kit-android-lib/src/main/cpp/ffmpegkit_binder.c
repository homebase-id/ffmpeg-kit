/*
 * Android Binder handler — Homebase gated version.
 *
 * Stock FFmpeg 8.0 introduced compat/android/binder.c which initializes
 * libbinder_ndk's thread pool on Android 15+ (API 35+) so MediaCodec HW
 * decode works correctly. fftools/ffmpeg.c invokes this from inside
 * `#if CONFIG_MEDIACODEC` at every ffmpeg_execute() entry.
 *
 * Problem: ABinderProcess_startThreadPool() SIGABRTs inside libbinder_ndk
 * when called from a process that isn't a proper binder client (e.g.
 * Android instrumented test runners). For chat-kmp's libx264 software-only
 * tests, calling this init is both unnecessary AND fatal.
 *
 * Fix: gate the init on whether MediaCodec will actually be used. The
 * argv scan in C11 ffmpeg_var_cleanup (fftools_ffmpeg.c) sets
 * `homebase_mediacodec_will_be_used` to 1 iff argv contains any
 * `_mediacodec` substring (covering h264_mediacodec, hevc_mediacodec,
 * etc.). When 0, we skip the init entirely.
 *
 * If real MediaCodec usage is detected AND the init still aborts in
 * some embedding context, the upstream logic already has fallback paths
 * for "libbinder_ndk.so missing" and "ABinderProcess_startThreadPool
 * symbol missing" — both return cleanly without aborting. The SIGABRT
 * only fires inside start_thread_pool() itself; if it does, the host
 * process dies, but at least the host code has explicitly opted in by
 * requesting MediaCodec.
 *
 * Symptom this gating fixes:
 *   F libc    : Fatal signal 6 (SIGABRT)
 *   F DEBUG   : #06 libffmpegkit.so (android_binder_threadpool_init_if_required+220)
 *   F DEBUG   : #07 libffmpegkit.so (ffmpeg_execute+351)
 * — fired in chat-kmp's instrumented test on libx264-only workloads.
 */

#if defined(__ANDROID__)

#include <dlfcn.h>
#include <stdint.h>
#include <stdlib.h>
#include <android/api-level.h>

#include "libavutil/log.h"
#include "compat/android/binder.h"

/* Set from C11 ffmpeg_var_cleanup based on argv scan for "_mediacodec".
 * Default 0 means: skip binder init unless explicitly requested. */
int homebase_mediacodec_will_be_used = 0;

#define THREAD_POOL_SIZE 1

static void *dlopen_libbinder_ndk(void)
{
    void *h = dlopen("libbinder_ndk.so", RTLD_NOW | RTLD_LOCAL);
    if (h != NULL)
        return h;

    av_log(NULL, AV_LOG_WARNING,
           "android/binder: unable to load libbinder_ndk.so: '%s'; "
           "skipping binder threadpool init (MediaCodec likely won't work)\n",
           dlerror());
    return NULL;
}

static void android_binder_threadpool_init(void)
{
    typedef int (*set_thread_pool_max_fn)(uint32_t);
    typedef void (*start_thread_pool_fn)(void);

    set_thread_pool_max_fn set_thread_pool_max = NULL;
    start_thread_pool_fn start_thread_pool = NULL;

    void *h = dlopen_libbinder_ndk();
    if (h == NULL)
        return;

    unsigned thread_pool_size = THREAD_POOL_SIZE;

    set_thread_pool_max =
        (set_thread_pool_max_fn) dlsym(h,
                                       "ABinderProcess_setThreadPoolMaxThreadCount");
    start_thread_pool =
        (start_thread_pool_fn) dlsym(h, "ABinderProcess_startThreadPool");

    if (start_thread_pool == NULL) {
        av_log(NULL, AV_LOG_WARNING,
               "android/binder: ABinderProcess_startThreadPool not found; "
               "skipping threadpool init (MediaCodec likely won't work)\n");
        return;
    }

    /* Homebase: stock upstream calls
     *     set_thread_pool_max(THREAD_POOL_SIZE = 1);
     * here to cap the pool at one worker. But the host process
     * (chat-kmp Android app, instrumented test runner, etc.) has
     * almost always ALREADY started a binder pool with size > 1
     * via the Android app framework. libbinder's
     * ProcessState::setThreadPoolMaxThreadCount() refuses to shrink
     * an already-started pool and aborts the process with:
     *   F ProcessState: Binder threadpool cannot be shrunk after starting
     * Skipping the call is safe: the existing pool serves us fine
     * (its default size is plenty for MediaCodec callback traffic), and
     * we still call start_thread_pool() below which is idempotent.
     *
     * This was confirmed by chat-kmp's compressVideo_h264MediaCodecSmoke
     * test — with set_thread_pool_max enabled, the test aborts inside
     * the call; with it skipped, MediaCodec encoding completes cleanly.
     */
    (void)set_thread_pool_max;
    (void)thread_pool_size;
    av_log(NULL, AV_LOG_DEBUG,
           "android/binder: skipping set_thread_pool_max (host process "
           "already manages binder pool size)\n");

    start_thread_pool();
    av_log(NULL, AV_LOG_DEBUG,
           "android/binder: ABinderProcess_startThreadPool() called\n");
}

void android_binder_threadpool_init_if_required(void)
{
    /* Homebase gate: skip the init entirely unless argv signaled MediaCodec
     * usage. This avoids the SIGABRT inside ABinderProcess_startThreadPool
     * for software-only ffmpeg invocations (the common case in chat-kmp). */
    if (!homebase_mediacodec_will_be_used) {
        av_log(NULL, AV_LOG_DEBUG,
               "android/binder: skipping init — no MediaCodec in argv "
               "(homebase gating, see ffmpegkit_binder.c).\n");
        return;
    }

#if __ANDROID_API__ >= 24
    if (android_get_device_api_level() < 35) {
        /* The thread-pool issue was introduced in Android 15 (API 35). */
        av_log(NULL, AV_LOG_DEBUG,
               "android/binder: API<35, no need to initialize a thread pool\n");
        return;
    }
    android_binder_threadpool_init();
#else
    av_log(NULL, AV_LOG_DEBUG,
           "android/binder: built with API<24, assuming not Android 15+\n");
#endif
}

#endif                          /* __ANDROID__ */
