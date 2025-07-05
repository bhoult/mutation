CC = gcc
CFLAGS = -Wall -Wextra -std=c99 -O2
TARGET = c_agent
SOURCE = c_agent.c

all: $(TARGET)

$(TARGET): $(SOURCE)
	$(CC) $(CFLAGS) -o $(TARGET) $(SOURCE)

clean:
	rm -f $(TARGET)

.PHONY: all clean