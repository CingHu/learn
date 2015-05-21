
#定义编译器与编译选项
CC=gcc
CFLAGS=-Wall -c -g
LINK= -Wall

RM=rm -rf

#编译临时文件存放目录


#编译目标文件
TARGET=confnet


#取目录下所有的.c文件
SOURCE = $(wildcard *.c)

#将.c结尾的名字改为.o结尾，作为编译目标
OBJS = $(patsubst %.c,%.o,$(SOURCE))


all:${TARGET}

${TARGET}:${OBJS}
	${CC} ${LINK} -o $@ $^

%.o: %.c
	${CC} ${CFLAGS} $< -o $@

#clean 删除文件
.PHONY:clean

clean:
	${RM} *.o ${TARGET}


