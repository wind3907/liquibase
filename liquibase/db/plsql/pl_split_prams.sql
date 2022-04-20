/****************************************************************************
** Date:        14-AUG-2020
** Description: Split the parameter using regexp and return as array
**
**    Modification History:
**    Date         Designer  Comments
**    --------     --------  ---------------------------------------------------
**    14-AUG-2020  NSEL0716  Split the parameter using regexp
**                  
****************************************************************************/
CREATE OR REPLACE FUNCTION F_SPLIT_PRAMS(
  prams IN VARCHAR2
) 
RETURN c_prams_list  AS
  v_prams_list c_prams_list := c_prams_list(); 
  v_prams_set SYS_REFCURSOR;
  lsn VARCHAR2(60);
  counter integer :=0; 
BEGIN
  OPEN v_prams_set FOR
    select regexp_replace(regexp_substr(prams,'(''.*?''|".*?"|\S+)', 1, level), '''|"','')
      FROM dual connect by regexp_substr(prams, '(''.*?''|".*?"|\S+)', 1, level) is not null;
  loop
    fetch v_prams_set into lsn; -- and other columns if needed
    exit when v_prams_set%notfound;
    counter := counter + 1; 
    v_prams_list.extend; 
    v_prams_list(counter)  := lsn; 
  end loop;
  RETURN v_prams_list;
END;
/
