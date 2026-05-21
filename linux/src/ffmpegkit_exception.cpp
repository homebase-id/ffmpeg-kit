/*
 * Copyright (c) 2018-2022 Taner Sener
 *
 * This file is part of FFmpegKit.
 *
 * FFmpegKit is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * FFmpegKit is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with FFmpegKit.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <stdlib.h>
#include "ffmpegkit_exception.h"

/** Holds information to implement exception handling. */
__thread jmp_buf ex_buf__;

/** Last exit code passed to exit_program(). */
__thread int longjmp_value = 0;

/*
 * Replaces stock fftools' raw exit() so a failed ffmpeg/ffprobe invocation
 * unwinds back to the wrapper layer instead of tearing down the host
 * process. Paired with setjmp(ex_buf__) inside ffmpeg_execute /
 * ffprobe_execute. Adding 1 to the longjmp value ensures setjmp's "did we
 * longjmp" probe returns non-zero even when ret == 0.
 */
extern "C" void exit_program(int ret) {
    longjmp_value = ret;
    longjmp(ex_buf__, ret + 1);
}
