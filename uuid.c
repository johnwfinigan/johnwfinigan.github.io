/*
 * Copyright (c) 2023 John Finigan
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */


#include <err.h>
#include <stdio.h>
#include <unistd.h>
#include <uuid.h>


int
main()
{
	if (pledge("stdio", NULL) == -1)
		err(1, "pledge");

	uint32_t 	status;
	uuid_t 		uuid;
	char           *uuidstr;

	uuid_create(&uuid, &status);
	if (status != uuid_s_ok)
		err(2, "uuid_create");

	uuid_to_string(&uuid, &uuidstr, &status);
	if (status != uuid_s_ok)
		err(3, "uuid_to_string");

	printf("%s\n", uuidstr);

	return 0;
}
