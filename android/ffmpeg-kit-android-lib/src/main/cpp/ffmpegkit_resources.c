/*
 * Homebase ffmpeg-kit — empty resource stubs for n8's fftools/resources/resman.c.
 *
 * FFmpeg 8 added an embedded-resources mechanism for ffprobe's mermaid
 * graph rendering (`-print_graphs`, `-print_graphs_format mermaid`). The
 * raw `graph.html` and `graph.css` files in `fftools/resources/` get
 * gzipped and embedded into `ff_graph_html_data` / `ff_graph_css_data`
 * via FFmpeg's resources Makefile (bin2c-style).
 *
 * Our wrapper build uses ndk-build, not FFmpeg's make pipeline, so the
 * resource .o files aren't produced. resman.c references the externs and
 * the wrapper link fails.
 *
 * chat-kmp never invokes `-print_graphs`, so the resource bytes are
 * unused at runtime. We define empty stubs so the link succeeds. If a
 * future consumer needs the mermaid output, replace these with the real
 * gzipped resource bytes (or bring FFmpeg's resources Makefile pipeline
 * into the wrapper build).
 */

#include <stdint.h>

const unsigned char ff_graph_html_data[] = { 0 };
const unsigned int  ff_graph_html_len    = 0;
const unsigned char ff_graph_css_data[]  = { 0 };
const unsigned int  ff_graph_css_len     = 0;
