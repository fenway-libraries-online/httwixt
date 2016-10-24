include config.mk

all: build/httwixt build/httwixt.cgi build/httwixt.fcgi

install-bin: build/httwixt
	install -d $(BIN)
	install $< $(BIN)/

install-cgi: build/httwixt.cgi
	install -d $(CGIBIN)
	install $< $(CGIBIN)/

install-fcgi: build/httwixt.fcgi
	install -d $(CGIBIN)
	install $< $(CGIBIN)/

install-pm: build/Twixt.pm
	install -d $(PM)/HTTP
	install $< $(PM)/HTTP/

build/Twixt.pm: Twixt.pm
	@install -d build
	install $< $@

build/httwixt: Twixt.pm
	@install -d build
	install $< $@

build/httwixt.cgi: Twixt.pm
	@install -d build
	install $< $@

build/httwixt.fcgi: Twixt.pm
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
