/****************************************************************************
** Date:        14-AUG-2020
** Description: A fixed sized array to store splitted parameter
**
**    Modification History:
**    Date         Designer  Comments
**    --------     --------  ---------------------------------------------------
**    14-AUG-2020  NSEL0716  Create fixed sized array
**                  
****************************************************************************/
CREATE OR REPLACE TYPE c_prams_list IS VARRAY (20) of VARCHAR2(60); 
/  
