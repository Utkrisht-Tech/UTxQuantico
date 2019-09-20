// Copyright (c) 2019 UTx10101 (Utkrisht Singh Chauhan). All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module HttpX

#flag -l Urlmon

#include <Urlmon.h>

fn download_file_with_progress(url, out string, cb, cb_finished voidptr) {
}

public fn download_file(url, out string) {
	C.URLDownloadToFile(0, url.to_wide(), out.to_wide(), 0, 0)
	/*
	if (res == S_OK) {
	println('Download Ok')
	# } else if(res == E_OUTOFMEMORY) {
	println('Buffer length invalid, or insufficient memory')
	# } else if(res == INET_E_DOWNLOAD_FAILURE) {
	println('URL is invalid')
	# } else {
	# printf("Download error: %d\n", res);
	# }
	*/
}