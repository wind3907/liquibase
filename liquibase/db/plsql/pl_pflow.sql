rem 
rem @(#) src/schema/plsql/pl_pflow.sql, swms, swms.9, 10.1.1 9/7/06 1.3
rem Usage: sqlplus USR/PWD pl_pflow.sql
rem
rem --- Maintenance history ---
rem 23-OCT-2001 prpksn Initial version
rem		This function will return either the Pick location when passing
rem		the Back Location or Return the Back location when passing
rem		the Pick location. If either could not be found, return the 
rem		value NONE.
create or replace PACKAGE  swms.pl_pflow as
  FUNCTION f_get_pick_loc (i_bck_logi_loc in varchar2) RETURN VARCHAR2;
  FUNCTION f_get_back_loc (i_pick_logi_loc in varchar2) RETURN VARCHAR2;

  g_palletflow_enable  sys_config.config_flag_val%TYPE := null;
end pl_pflow;
/

create or replace PACKAGE BODY swms.pl_pflow AS
  FUNCTION f_get_pick_loc (i_bck_logi_loc in varchar2) RETURN varchar2 IS
   l_location     loc_reference.plogi_loc%TYPE;
   cursor get_pick_cur is
    select plogi_loc
    from loc_reference
    where bck_logi_loc = i_bck_logi_loc;
 begin
   open get_pick_cur;
   fetch get_pick_cur into l_location;
   if get_pick_cur%FOUND then
      return l_location;
   else
      return 'NONE';
   end if;
   close get_pick_cur;
 end f_get_pick_loc;
/* *********************************************************************** */
 FUNCTION f_get_back_loc (i_pick_logi_loc in varchar2) RETURN varchar2 IS
   l_location     loc_reference.plogi_loc%TYPE;
   cursor get_back_cur is
    select bck_logi_loc
    from loc_reference
    where plogi_loc = i_pick_logi_loc;
 begin
   open get_back_cur;
   fetch get_back_cur into l_location;
   if get_back_cur%FOUND then
      return l_location;
   else
      return 'NONE';
   end if;
   close get_back_cur;
 end f_get_back_loc;
end pl_pflow;
/
