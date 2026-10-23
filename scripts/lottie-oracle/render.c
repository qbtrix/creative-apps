/*
 * scripts/lottie-oracle/render.c: the reference player's one-frame renderer.
 *
 *   render <file.json> <frame> <w> <h>  >  frame.rgba
 *
 * Loads a Lottie file through ThorVG's public C API (thorvg_capi.h), seeks to
 * <frame> (0-based, ip-relative, below the total frame count), draws it fitted
 * into <w> x <h> over opaque white, and writes w * h * 4 bytes of raw RGBA
 * (row-major, top row first, straight alpha) to stdout. Errors go to stderr
 * with a non-zero exit. Built by scripts/lottie-oracle/build; see README.md.
 * Written for this repo against ThorVG's documented C API; no ThorVG code.
 */
#include <errno.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <thorvg_capi.h>

static int fail(const char *what) {
    fprintf(stderr, "render: %s\n", what);
    return 1;
}

static int parse_dim(const char *s, uint32_t *out) {
    char *end = NULL;
    errno = 0;
    long v = strtol(s, &end, 10);
    if (errno != 0 || end == s || *end != '\0' || v < 1 || v > 8192) return 0;
    *out = (uint32_t)v;
    return 1;
}

int main(int argc, char **argv) {
    if (argc != 5) {
        fprintf(stderr, "usage: render <file.json> <frame> <w> <h>  (raw RGBA on stdout)\n");
        return 2;
    }
    char path[PATH_MAX];
    if (!realpath(argv[1], path)) return fail("cannot resolve the Lottie path");
    char *end = NULL;
    float frame = strtof(argv[2], &end);
    if (end == argv[2] || *end != '\0' || frame < 0) return fail("frame must be a number >= 0");
    uint32_t w = 0, h = 0;
    if (!parse_dim(argv[3], &w) || !parse_dim(argv[4], &h)) return fail("w and h must be 1...8192");

    if (tvg_engine_init(0) != TVG_RESULT_SUCCESS) return fail("tvg_engine_init failed");
    uint32_t *buffer = calloc((size_t)w * h, sizeof(uint32_t));
    if (!buffer) return fail("out of memory");

    Tvg_Canvas canvas = tvg_swcanvas_create(TVG_ENGINE_OPTION_DEFAULT);
    if (!canvas) return fail("tvg_swcanvas_create failed");
    /* ABGR8888S: un-premultiplied; the uint32 holds A<<24 | B<<16 | G<<8 | R. */
    if (tvg_swcanvas_set_target(canvas, buffer, w, w, h, TVG_COLORSPACE_ABGR8888S) != TVG_RESULT_SUCCESS)
        return fail("tvg_swcanvas_set_target failed");

    Tvg_Paint background = tvg_shape_new();
    tvg_shape_append_rect(background, 0, 0, (float)w, (float)h, 0, 0, true);
    tvg_shape_set_fill_color(background, 255, 255, 255, 255);
    tvg_canvas_add(canvas, background);

    Tvg_Animation animation = tvg_animation_new();
    Tvg_Paint picture = tvg_animation_get_picture(animation);
    if (tvg_picture_load(picture, path) != TVG_RESULT_SUCCESS) return fail("ThorVG could not load the Lottie");
    float total = 0;
    tvg_animation_get_total_frame(animation, &total);
    if (frame >= total) {
        fprintf(stderr, "render: frame %g is past the last frame (total %g)\n", frame, total);
        return 1;
    }
    /* INSUFFICIENT_CONDITION only means the animation already sits on that frame. */
    Tvg_Result seek = tvg_animation_set_frame(animation, frame);
    if (seek != TVG_RESULT_SUCCESS && seek != TVG_RESULT_INSUFFICIENT_CONDITION) return fail("set_frame failed");
    tvg_picture_set_size(picture, (float)w, (float)h);

    /* The animation owns the picture: hold a reference so the canvas never frees it. */
    tvg_paint_ref(picture);
    if (tvg_canvas_add(canvas, picture) != TVG_RESULT_SUCCESS) return fail("tvg_canvas_add failed");
    if (tvg_canvas_draw(canvas, true) != TVG_RESULT_SUCCESS) return fail("tvg_canvas_draw failed");
    if (tvg_canvas_sync(canvas) != TVG_RESULT_SUCCESS) return fail("tvg_canvas_sync failed");

    unsigned char *rgba = malloc((size_t)w * h * 4);
    if (!rgba) return fail("out of memory");
    for (size_t i = 0; i < (size_t)w * h; i++) {
        uint32_t p = buffer[i];
        rgba[i * 4 + 0] = (unsigned char)(p & 0xff);
        rgba[i * 4 + 1] = (unsigned char)((p >> 8) & 0xff);
        rgba[i * 4 + 2] = (unsigned char)((p >> 16) & 0xff);
        rgba[i * 4 + 3] = (unsigned char)((p >> 24) & 0xff);
    }
    size_t bytes = (size_t)w * h * 4;
    int ok = fwrite(rgba, 1, bytes, stdout) == bytes && fflush(stdout) == 0;

    tvg_canvas_destroy(canvas);
    tvg_paint_unref(picture, false);
    tvg_animation_del(animation);
    tvg_engine_term();
    free(rgba);
    free(buffer);
    return ok ? 0 : fail("short write to stdout");
}
