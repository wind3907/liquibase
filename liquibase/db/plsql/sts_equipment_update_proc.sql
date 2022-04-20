CREATE OR REPLACE
PROCEDURE        SWMS.STS_EQUIPMENT_UPDATE         (
sz_route_no IN VARCHAR,
sz_route_date IN VARCHAR,
sz_truck_no IN VARCHAR,
sz_cust_id IN VARCHAR,
sz_barcode IN VARCHAR,
sz_status IN VARCHAR,
sz_quantity IN VARCHAR,
sz_add_date IN VARCHAR
)  IS

ov_route_date DATE := TO_DATE( sz_route_date, 'YYYYMMDDHH24MISS');
ov_add_date DATE := TO_DATE( sz_add_date, 'YYYYMMDDHH24MISS');
temp_quantity NUMBER := to_number(sz_quantity);
v_quantity_remain NUMBER;
v_add_date DATE;

CURSOR equip IS
  SELECT QTY - QTY_RETURNED AS QTY_REMAIN, ADD_DATE
  FROM STS_EQUIPMENT
  WHERE CUST_ID = sz_cust_id AND 
        BARCODE = sz_barcode AND
        STATUS = 'D' AND ( QTY - QTY_RETURNED > 0 )
  ORDER BY ADD_DATE ASC;

BEGIN

INSERT INTO sts_log VALUES(SYSDATE, 'DBG', 'Hello Toyko' );

  IF ( sz_status = 'P' ) THEN
  
     BEGIN

        /* Resolve old drops with this qty */
        OPEN equip;
        FETCH equip into v_quantity_remain, v_add_date;
        WHILE equip%FOUND LOOP
        
            IF( v_quantity_remain <= temp_quantity ) THEN

INSERT INTO sts_log VALUES(SYSDATE, 'DBG1', 'Whats going on');

                /* Use part of our quantity and all of this entry's qty */
                temp_quantity := temp_quantity - v_quantity_remain;
                UPDATE STS_EQUIPMENT SET QTY_RETURNED = QTY WHERE
                   CUST_ID = sz_cust_id AND 
                   BARCODE = sz_barcode AND ADD_DATE = v_add_date;
                
            ELSE
INSERT INTO sts_log VALUES(SYSDATE, 'DBG2', sz_cust_id );

                /* Use all our quantity and apply it to this entry */
                UPDATE STS_EQUIPMENT 
                   SET QTY_RETURNED = QTY_RETURNED + temp_quantity WHERE
                   CUST_ID = sz_cust_id AND 
                   BARCODE = sz_barcode AND ADD_DATE = v_add_date;
                   
                temp_quantity := 0;
                   
            END IF;
            

            /* We are done when there is no more qty to give out */                
            EXIT WHEN temp_quantity = 0;
            FETCH equip into v_quantity_remain, v_add_date;
        END LOOP;      

     END;
  END IF;

  /* Now insert our new entry */

  INSERT INTO  STS_EQUIPMENT (ROUTE_NO, TRUCK_NO, CUST_ID, BARCODE, 
                              STATUS, QTY, QTY_RETURNED, ADD_DATE)
  VALUES ( sz_route_no, sz_truck_no, sz_cust_id, sz_barcode, 
           sz_status, to_number(sz_quantity), 0, ov_add_date);

END;
/
grant execute on swms.STS_EQUIPMENT_UPDATE to PUBLIC;

create or replace public synonym STS_EQUIPMENT_UPDATE for SWMS.STS_EQUIPMENT_UPDATE;

