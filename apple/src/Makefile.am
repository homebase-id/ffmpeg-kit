lib_LTLIBRARIES = libffmpegkit.la

libffmpegkit_la_LIBADD = @FFMPEG_FRAMEWORKS@

libffmpegkit_la_SOURCES = \
    AbstractSession.m \
    ArchDetect.m \
    AtomicLong.m \
    Chapter.m \
    FFmpegKit.m \
    FFmpegKitConfig.m \
    FFmpegSession.m \
    FFprobeKit.m \
    FFprobeSession.m \
    Log.m \
    MediaInformation.m \
    MediaInformationJsonParser.m \
    MediaInformationSession.m \
    Packages.m \
    ReturnCode.m \
    Statistics.m \
    StreamInformation.m \
    ffmpegkit_exception.m \
    fftools_cmdutils.c \
    fftools_ffmpeg.c \
    fftools_ffmpeg_dec.c \
    fftools_ffmpeg_demux.c \
    fftools_ffmpeg_enc.c \
    fftools_ffmpeg_filter.c \
    fftools_ffmpeg_hw.c \
    fftools_ffmpeg_mux.c \
    fftools_ffmpeg_mux_init.c \
    fftools_ffmpeg_opt.c \
    fftools_ffmpeg_sched.c \
    fftools_ffprobe.c \
    fftools_opt_common.c \
    fftools_sync_queue.c \
    fftools_thread_queue.c \
    fftools_graphprint.c \
    fftools_resman.c \
    fftools_avtextformat.c \
    fftools_tf_compact.c \
    fftools_tf_default.c \
    fftools_tf_flat.c \
    fftools_tf_ini.c \
    fftools_tf_json.c \
    fftools_tf_mermaid.c \
    fftools_tf_xml.c \
    fftools_tw_avio.c \
    fftools_tw_buffer.c \
    fftools_tw_stdout.c

include_HEADERS = \
    AbstractSession.h \
    ArchDetect.h \
    AtomicLong.h \
    Chapter.h \
    FFmpegKit.h \
    FFmpegKitConfig.h \
    FFmpegSession.h \
    FFmpegSessionCompleteCallback.h \
    FFprobeKit.h \
    FFprobeSession.h \
    FFprobeSessionCompleteCallback.h \
    Level.h \
    Log.h \
    LogCallback.h \
    LogRedirectionStrategy.h \
    MediaInformation.h \
    MediaInformationJsonParser.h \
    MediaInformationSession.h \
    MediaInformationSessionCompleteCallback.h \
    Packages.h \
    ReturnCode.h \
    Session.h \
    SessionState.h \
    Statistics.h \
    StatisticsCallback.h \
    StreamInformation.h \
    ffmpegkit_exception.h \
    fftools_cmdutils.h \
    fftools_ffmpeg.h \
    fftools_ffmpeg_mux.h \
    fftools_ffmpeg_sched.h \
    fftools_ffmpeg_utils.h \
    fftools_fopen_utf8.h \
    fftools_opt_common.h \
    fftools_sync_queue.h \
    fftools_thread_queue.h \
    fftools_graphprint.h \
    fftools_resman.h \
    fftools_avtextformat.h \
    fftools_avtextwriters.h \
    fftools_tf_internal.h \
    fftools_tf_mermaid.h

libffmpegkit_la_CFLAGS = $(CFLAGS)
libffmpegkit_la_OBJCFLAGS = $(CFLAGS)
libffmpegkit_la_CXXFLAGS = $(CXXFLAGS)
libffmpegkit_la_LDFLAGS = $(LDFLAGS)
