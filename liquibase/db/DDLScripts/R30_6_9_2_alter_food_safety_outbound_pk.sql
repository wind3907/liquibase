DECLARE
        n_count                                 PLS_INTEGER;
	SQL_stmt                                VARCHAR2(2000 CHAR);
	v_column_exists                 NUMBER := 0;
BEGIN
   SELECT count(*)
   into n_count
   FROM all_objects
   WHERE owner = 'SWMS'
   AND object_name = 'FOOD_SAFETY_OUTBOUND_PK';
   
   IF n_count = 0 THEN
      SQL_stmt :=
	 'alter table FOOD_SAFETY_OUTBOUND add constraint FOOD_SAFETY_OUTBOUND_PK primary key (MANIFEST_NO, STOP_NO, OBLIGATION_NO, PROD_ID)';
         EXECUTE IMMEDIATE SQL_stmt;
   ELSE

      SQL_stmt :=
             'alter table FOOD_SAFETY_OUTBOUND drop constraint FOOD_SAFETY_OUTBOUND_PK';
      EXECUTE IMMEDIATE SQL_stmt;
      SQL_stmt :=
	 'alter table FOOD_SAFETY_OUTBOUND add constraint FOOD_SAFETY_OUTBOUND_PK primary key (MANIFEST_NO, STOP_NO, OBLIGATION_NO, PROD_ID)';
      EXECUTE IMMEDIATE SQL_stmt;
   END IF;
END;
/
