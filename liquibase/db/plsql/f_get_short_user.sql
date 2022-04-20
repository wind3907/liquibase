CREATE OR REPLACE FUNCTION swms.f_get_short_user
  (p_short_batch_no IN VARCHAR2,
   p_location IN VARCHAR2,
   p_prod_id IN VARCHAR2,
   p_batch_no IN VARCHAR2,
   p_order_id IN VARCHAR2,
   p_order_line_id VARCHAR2) RETURN VARCHAR2 IS
/**************************************************************************/
/* Function name : f_get_short_user                                       */
/* Desctiption   : Queries the FLOAT_HIST table to rerieve the the user   */
/*                 selecting the short.                                   */
/**************************************************************************/
  l_short_user_id float_hist.short_user_id%TYPE;
BEGIN
  SELECT short_user_id
    INTO l_short_user_id
    FROM float_hist
   WHERE short_batch_no = p_short_batch_no
     AND src_loc = p_location
     AND prod_id  = p_prod_id
     AND batch_no = p_batch_no
     AND order_id = p_order_id
     AND order_line_id = p_order_line_id;
  RETURN l_short_user_id;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN (NULL);
  WHEN OTHERS THEN
    RETURN (SQLCODE);
END;
/

CREATE OR REPLACE PUBLIC SYNONYM f_get_short_user FOR swms.f_get_short_user;

GRANT EXECUTE ON f_get_short_user TO SWMS_VIEWER;
GRANT EXECUTE ON f_get_short_user TO SWMS_USER;
