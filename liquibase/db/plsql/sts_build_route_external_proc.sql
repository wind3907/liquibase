
--Path needs to be altered for final location of STS installed components
BEGIN
$if dbms_db_version.ver_le_11 $then
	EXECUTE IMMEDIATE 'create or replace library swms.stsroute_lib as ''/swms/curr/bin/sts/libstsroute.so''';
$else
	EXECUTE IMMEDIATE 'create or replace library swms.stsroute_lib as ''/swms/curr/bin/sts/libstsroute.so'' AGENT ''EXTPROC_LINK''';
$end
END;
/
show sqlcode
show errors

CREATE OR REPLACE FUNCTION SWMS.STS_BUILD_ROUTE_FILES
( RouteNo IN VARCHAR2, RouteDate IN VARCHAR2 ) RETURN PLS_INTEGER
AS
		EXTERNAL
		LIBRARY stsroute_lib
		NAME "stsRoute"
		LANGUAGE C
                WITH CONTEXT
		PARAMETERS( RouteNo STRING, RouteDate STRING, CONTEXT );

--END;

/
grant execute on swms.stsroute_lib to PUBLIC;

grant execute on SWMS.STS_BUILD_ROUTE_FILES to PUBLIC;

create or replace public synonym STS_BUILD_ROUTE_FILES for SWMS.STS_BUILD_ROUTE_FILES;

