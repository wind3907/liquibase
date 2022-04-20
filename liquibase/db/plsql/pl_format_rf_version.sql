CREATE OR REPLACE FUNCTION format_rf_version (host_version IN VARCHAR)
RETURN VARCHAR AS
 l_dotPos NUMBER;
 l_formatted_version RF_CLIENT_VERSION.CLIENT_VERSION%TYPE := NULL; 
 type version_component_array is varray(4) of varchar2(5);
 l_version_component version_component_array := version_component_array(null,null,null,null);
 l_version RF_CLIENT_VERSION.CLIENT_VERSION%TYPE;
 
BEGIN
 l_version := host_version;
 
    FOR i IN 1..l_version_component.COUNT
    LOOP
       l_dotPos := INSTR(l_version,'.',1,1);
          IF (l_dotPos > 0) THEN
               l_version_component(i) := SUBSTR(l_version,1,l_dotPos - 1);
               l_version := SUBSTR(l_version,l_dotPos + 1);
          ELSE
               l_version_component(i) := l_version;
               l_version := NULL;
          END IF;

       l_version_component(i) := to_char(to_number('0' || l_version_component(i)));

       IF (l_formatted_version IS NULL) THEN
          l_formatted_version := l_version_component(i);
       ELSE
          l_formatted_version := l_formatted_version || '.' || l_version_component(i);
       END IF;
   END LOOP;
   
  RETURN(l_formatted_version);
END;
/

CREATE OR REPLACE PUBLIC SYNONYM FORMAT_RF_VERSION FOR SWMS.FORMAT_RF_VERSION;

GRANT EXECUTE ON FORMAT_RF_VERSION TO SWMS_USER;
GRANT EXECUTE ON FORMAT_RF_VERSION TO SWMS_VIEWER;
