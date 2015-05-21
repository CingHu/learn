CC=gcc
CFLAGS=-Wall
BIN=checkip
FLAG_LIBXML=`pkg-config libxml-2.0 --cflags`

MAIN: main.o passwd.o config.o request.o response.o inetface.o inetconf.o communicate.o LIB
	${CC} ${CFLAGS} -o ${BIN} \
	main.o passwd.o request.o response.o inetface.o inetconf.o communicate.o \
	config.o \
	lib/utils.o lib/network.o lib/buffer.o lib/logger.o lib/header_list.o \
	lib/string_list.o lib/http_request.o lib/http_response.o \
	`pkg-config libssl --libs` `pkg-config libxml-2.0 --libs` -lcrypt

main.o: main.c
	${CC} ${CFLAGS} -c main.c 

passwd.o: passwd.c
	${CC} ${CFLAGS} -c passwd.c

request.o: request.c
	${CC} ${CFLAGS} -c request.c ${FLAG_LIBXML}

response.o: response.c
	${CC} ${CFLAGS} -c response.c ${FLAG_LIBXML}

inetface.o: inetface.c
	${CC} ${CFLAGS} -c inetface.c

inetconf.o: inetconf.c
	${CC} ${CFLAGS} -c inetconf.c

communicat.o: communicate.c
	${CC} ${CFLAGS} -c communicate.c

config.o: config.c
	${CC} ${CFALGS} -c config.c


LIB:
	cd lib; make; cd ..

clean:
	rm -rf *.o $(BIN)
	cd lib;make clean;cd ..

