CC=gcc
CFLAGS=-Wall -c -g

LIBRARY: utils.o network.o buffer.o string_list.o header_list.o logger.o \
	http_request.o http_response.o

utils.o: utils.c
	${CC} ${CFLAGS} utils.c

logger.o: logger.c
	${CC} ${CFLAGS} logger.c

network.o: network.c
	${CC} ${CFLAGS} network.c

buffer.o: buffer.c
	${CC} ${CFLAGS} buffer.c

string_list.o: string_list.c
	${CC} ${CFLAGS} string_list.c

header_list.o: header_list.c
	${CC} ${CFLAGS} header_list.c

http_request.o: http_request.c
	${CC} ${CFLAGS} http_request.c

http_response.o: http_response.c
	${CC} ${CFLAGS} http_response.c

clean:
	rm -rf *.o















