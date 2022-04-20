/****************************************************************************
** Date:       02/17/2020 
** File:       type_lm_distance_obj.sql
**
**             Script for creating objects for lm distance
**    - SCRIPTS
**
**    Modification History:
**    Date       Designer Comments
**    --------   -------- ---------------------------------------------------
**   02/17/2020      Infosys           Initial version0.0  
**
****************************************************************************/
create or replace TYPE lmd_distance_obj FORCE AS OBJECT 
(
    accel_distance	NUMBER,
    decel_distance	NUMBER,
    travel_distance	NUMBER,
    total_distance	NUMBER,
    tia_time		NUMBER,
    distance_rate	NUMBER
)
/

create or replace TYPE lmd_batch_rec_obj FORCE AS OBJECT (
    batch_no                         VARCHAR2(13),
    parent_batch_no                  VARCHAR2(13),
    src_loc                          VARCHAR2(10),
    dest_loc                         VARCHAR2(10),
    src_dock                         VARCHAR2(2),
    dest_dock                        VARCHAR2(2),
    user_id                          VARCHAR2(30),
    miniload_reserve_put_back_flag   VARCHAR2(1)
)
/

GRANT EXECUTE ON lmd_distance_obj TO SWMS_USER;
GRANT EXECUTE ON lmd_batch_rec_obj TO SWMS_USER;
