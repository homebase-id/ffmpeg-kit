ifeq ($(MY_LTS_POSTFIX),-lts)
    LOCAL_PATH := $(call my-dir)/../../../prebuilt/android-$(TARGET_ARCH)-lts/ffmpeg/lib
else
    LOCAL_PATH := $(call my-dir)/../../../prebuilt/android-$(TARGET_ARCH)/ffmpeg/lib
endif

MY_ARM_MODE := arm

include $(CLEAR_VARS)
LOCAL_ARM_MODE := $(MY_ARM_MODE)
LOCAL_MODULE := libavcodec
LOCAL_SRC_FILES := libavcodec.so
include $(PREBUILT_SHARED_LIBRARY)

include $(CLEAR_VARS)
LOCAL_ARM_MODE := $(MY_ARM_MODE)
LOCAL_MODULE := libavfilter
LOCAL_SRC_FILES := libavfilter.so
include $(PREBUILT_SHARED_LIBRARY)

include $(CLEAR_VARS)
LOCAL_ARM_MODE := $(MY_ARM_MODE)
LOCAL_MODULE := libavdevice
LOCAL_SRC_FILES := libavdevice.so
include $(PREBUILT_SHARED_LIBRARY)

include $(CLEAR_VARS)
LOCAL_ARM_MODE := $(MY_ARM_MODE)
LOCAL_MODULE := libavformat
LOCAL_SRC_FILES := libavformat.so
include $(PREBUILT_SHARED_LIBRARY)

include $(CLEAR_VARS)
LOCAL_ARM_MODE := $(MY_ARM_MODE)
LOCAL_MODULE := libavutil
LOCAL_SRC_FILES := libavutil.so
LOCAL_EXPORT_C_INCLUDES := $(LOCAL_PATH)/../include
include $(PREBUILT_SHARED_LIBRARY)

include $(CLEAR_VARS)
LOCAL_ARM_MODE := $(MY_ARM_MODE)
LOCAL_MODULE := libswresample
LOCAL_SRC_FILES := libswresample.so
include $(PREBUILT_SHARED_LIBRARY)

include $(CLEAR_VARS)
LOCAL_ARM_MODE := $(MY_ARM_MODE)
LOCAL_MODULE := libswscale
LOCAL_SRC_FILES := libswscale.so
include $(PREBUILT_SHARED_LIBRARY)

# U20 (n8): libpostproc removed from FFmpeg 8.x mainline. The module block
# that was here (U9 follow-up) is gone; postproc.so is no longer emitted by
# FFmpeg n8's build, so ndk-build can't find it.
