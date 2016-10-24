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
	rm -Rf build dist httwixt-*

dist: httwixt-$(VERSION).tar.gz

httwixt-$(VERSION).tar.gz: httwixt-$(VERSION)
	tar -czf $@ --exclude=old $<
	rm -Rf $<

httwixt-$(VERSION): clean
	install -d dist
	cp -rl `ls . | fgrep -v -w dist` dist/
	mv dist httwixt-$(VERSION)

.PHONY: install-bin install-cgi install-fcgi install-pm clean dist
