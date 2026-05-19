/*
 * Android Binder handler — Homebase no-op stub.
 *
 * Stock FFmpeg 8.0 introduced compat/android/binder.c which initializes
 * the libbinder_ndk thread pool on Android 15+ (API 35+) so MediaCodec
 * HW decode works correctly. The stock implementation dlopens
 * libbinder_ndk.so, dlsyms ABinderProcess_startThreadPool, and calls
 * it. fftools/ffmpeg.c then invokes android_binder_threadpool_init_if_required()
 * unconditionally inside #if CONFIG_MEDIACODEC at every ffmpeg_execute()
 * entry.
 *
 * On the chat-kmp instrumented test emulator (API 36, x86_64), calling
 * the upstream init function SIGABRTs deep inside libbinder_ndk's
 * ABinderProcess_startThreadPool — likely because the host process
 * isn't a proper binder client (we're running as an instrumented test,
 * not a normal app with system service bindings). The crash makes the
 * baseline libx264 software-encoding test (which doesn't need
 * MediaCodec at all) fail to start.
 *
 * Trade-off accepted: stub the function so it always returns without
 * touching libbinder_ndk. chat-kmp's actual use of ffmpeg-kit is
 * libx264 / aac software codecs, plus -c:v h264_mediacodec
 * (HW-accelerated). The HW path may not work on Android 15+ without
 * the threadpool init — if that becomes an issue, revisit by:
 *   (a) gating the init on a runtime probe (e.g. only init when
 *       MediaCodec is actually about to be opened), or
 *   (b) catching the abort via sigaction (ugly), or
 *   (c) replacing libbinder_ndk dlsym with a direct call that doesn't
 *       abort on misuse.
 *
 * Symptom from chat-kmp instrumented test (n8.1.1 AAR, API 36):
 *   F libc    : Fatal signal 6 (SIGABRT)
 *   F DEBUG   : #06 libffmpegkit.so (android_binder_threadpool_init_if_required+220)
 *   F DEBUG   : #07 libffmpegkit.so (ffmpeg_execute+351)
 */

#if defined(__ANDROID__)

#include <stddef.h>

#include "libavutil/log.h"
#include "compat/android/binder.h"

void android_binder_threadpool_init_if_required(void)
{
    /* Homebase: no-op. See file header for rationale. */
    av_log(NULL, AV_LOG_DEBUG,
           "android/binder: Homebase no-op stub — skipping threadpool init "
           "(MediaCodec HW decode on Android 15+ may need real init).\n");
}

#endif                          /* __ANDROID__ */
