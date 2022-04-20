SET ECHO OFF
SET LINESIZE 300
SET PAGESIZE 60
SET SERVEROUTPUT ON SIZE UNLIMITED
/*
**********************************************************************************
** File:       R52_0_DML_OPCO4062_add_loc_stat.sql
**
** Purpose:    Add xdock types to cross_dock_type table
**
** Modification History:
**   Date         Designer  Comments
**   -----------  --------- ------------------------------------------------------
**   03/10/2022   kchi7065  Created
**********************************************************************************
*/

DECLARE
  l_dummy varchar2(1);
  l_status loc_stat.status%type;
  l_desc loc_stat.descrip%type;

  CURSOR chk_loc_stat IS 
    SELECT 'X'
      FROM LOC_STAT
     WHERE STATUS = l_status;
     
BEGIN
  l_status := 'RAC';
  l_desc := 'Mobile Rack';
  OPEN chk_loc_stat;
  FETCH chk_loc_stat INTO l_dummy;

  IF ( chk_loc_stat%found ) THEN
  
      dbms_output.put_line (l_status||' already exists.');

    ELSIF ( chk_loc_stat%notfound ) THEN

      INSERT INTO loc_stat (status,descrip) 
      values
      (l_status, l_desc);

      dbms_output.put_line (l_status||' added.');
      commit;

  END IF;
  
  CLOSE chk_loc_stat;

END;
/
