include config.mk

all: build/twixt build/twixt.cgi build/twixt.fcgi

install-bin: build/twixt
	install -d $(BIN)
	install $< $(BIN)/

install-cgi: build/twixt.cgi
	install -d $(CGIBIN)
	install $< $(CGIBIN)/

install-fcgi: build/twixt.fcgi
	install -d $(CGIBIN)
	install $< $(CGIBIN)/

install-pm: build/Twixt.pm
	install -d $(PM)/HTTP
	install $< $(PM)/HTTP/

build/Twixt.pm: Twixt.pm
	@install -d build
	install $< $@

build/twixt: Twixt.pm
	@install -d build
	install $< $@

build/twixt.cgi: Twixt.pm
	@install -d build
	install $< $@

build/twixt.fcgi: Twixt.pm
	@install -d build
	install $< $@

clean:
	rm -Rf build

.PHONY: clean install-bin install-cgi install-fcgi install-pm
