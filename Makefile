
BIN_DIR := ./node_modules/.bin
COFFEE  := $(BIN_DIR)/coffee
MOCHA   := $(BIN_DIR)/mocha
DOCCO   := $(BIN_DIR)/docco
SWEETEN := $(BIN_DIR)/sweeten-docco

all: coffee docs

coffee:
	$(COFFEE) -c -o lib *.coffee

test:
	$(MOCHA) --compilers coffee:coffee-script test/*.coffee

docs:
	$(DOCCO) *.coffee && $(SWEETEN)

clean:
	rm -rf docs lib

.PHONY: all coffee test docs clean
