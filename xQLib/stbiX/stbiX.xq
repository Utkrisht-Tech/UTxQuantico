// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module stbiX

import gl

#flag   -I @XQROOT/thirdParty/stb_image

#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"
struct Image {
mut:
	width           int
	height          int
	no_of_channels  int
	ok              bool
	data            voidptr
	extension       string
}

public fn load(path string) Image {
	extension := path.all_after('.')
	mut res := Image {
		ok: true
		extension: extension
		data: 0
	}
	flag := if extension == 'png' { C.STBI_rgb_alpha } else { 0 }
	res.data = C.stbi_load(path.str, &res.width, &res.height,	&res.no_of_channels, flag)
	if isnull(res.data) {
		println('stbiX Image failed to load')
		exit(1)
	}
	return res
}

public fn (img Image) free() {
	C.stbi_image_free(img.data)
}

public fn (img Image) tex_image_2d() {
	mut rgb_flag := C.GL_RGB
	if img.extension == 'png' {
		rgb_flag = C.GL_RGBA
	}
	C.glTexImage2D(C.GL_TEXTURE_2D, 0, rgb_flag, img.width, img.height, 0, rgb_flag, C.GL_UNSIGNED_BYTE, img.data)
}

public fn set_flip_vertically_on_load(val bool) {
	C.stbi_set_flip_vertically_on_load(val)
}