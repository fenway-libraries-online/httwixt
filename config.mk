PREFIX := $(shell perl -MConfig -e 'print "$$Config{siteprefix}\n"')
BIN := $(shell perl -MConfig -e 'print "$$Config{installsitebin}\n"')
PM := $(shell perl -MConfig -e 'print "$$Config{installsitelib}\n"')
CGIBIN := $(PREFIX)/cgi-bin
