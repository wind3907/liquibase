SQL			= $(wildcard *.sql)
PRINT_SRCS  = $(SQL)
PRINT_LSTS  =

depend:
	@echo "No dependencies to set in this directory"


#***********************************************************************
# components
#***********************************************************************

components: setperm 
	@echo "No components to build in this directory"

setperm:
	@echo "No permissions to set in this directory"


#***********************************************************************
# install
#***********************************************************************

install: install.dirs install.scripts

install.dirs: schemas.dir

schemas.dir:
	@if [ ! -d $(SCHEMAS) ]; then \
	    mkdir $(SCHEMAS); \
	    chown $(SWMS_USER):$(SWMS_GROUP) $(SCHEMAS); \
	    chmod $(DIRPERMISSIONS) $(SCHEMAS); \
	fi

install.scripts : $(SQL)
	set -x;for f in $?; do	\
		$(INSTALL) $(INSTALL_DIROPT) $(SCHEMAS) $(SQLINSTALLFLAGS) $$f;	\
	done


#***********************************************************************
# uninstall
#***********************************************************************

uninstall: uninstall.scripts

uninstall.scripts: $(SQL)
	set -x;for f in $^; do \
		$(RM) $(RMFLAGS) $(SCHEMAS)/$$f;	\
	done


#***********************************************************************
# clean
#***********************************************************************

clean.all: clean

clean: 
	@echo "Nothing to clean in this directory"


#***********************************************************************
# print
#***********************************************************************

print: print.srcs print.make

print.srcs: $(SQL)
	-$(LPR) $(LPRFLAGS) $(SQL)

print.lsts:
	-$(LPR) $(LPRFLAGS) $(PRINT_LSTS)

print.make:
	-$(LPR) $(LPRFLAGS) ./makefile
