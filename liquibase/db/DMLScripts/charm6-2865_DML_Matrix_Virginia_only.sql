
-- January 2015
-- Symbotic DML script for Virginia.
--
--------INSERT STATEMENT FOR RULES TABLE------

INSERT into RULES (RULE_ID,RULE_TYPE,RULE_DESC   ,   DEF, MAINTAINABLE)
    VALUES        (5,     'PUT',    'MATRIX AS/RS',   'N', 'N');

------INSERT ZONE

INSERT INTO ZONE 
(ZONE_ID,ZONE_TYPE,RULE_ID,WAREHOUSE_ID,INDUCTION_LOC,OUTBOUND_LOC,DESCRIP,Z_AREA_CODE, Z_SUB_AREA_CODE)
VALUES 
('LXPUT','PUT',    5,      '000',         'LX1111',     'LX9999',   'Matrix PUT Zone','D', 'D');


INSERT INTO ZONE 
(ZONE_ID,ZONE_TYPE,RULE_ID,WAREHOUSE_ID,INDUCTION_LOC,OUTBOUND_LOC,DESCRIP,Z_AREA_CODE, Z_SUB_AREA_CODE)
VALUES 
('LXPKD','PIK',    5,      '000',         'LX1111',     'LX9999',   'Matrix PIK FOOD Zone','D', 'D');


INSERT INTO ZONE 
(ZONE_ID,ZONE_TYPE,RULE_ID,WAREHOUSE_ID,INDUCTION_LOC,OUTBOUND_LOC,DESCRIP,Z_AREA_CODE, Z_SUB_AREA_CODE)
VALUES 
('LXPKC','PIK',    5,      '000',         'LX1111',     'LX9999',   'Matrix PIK Caustic Zone','D', 'D');


-------INSERT STATEMENT FOR THE SLOT_TYPE------

INSERT into slot_type (SLOT_TYPE,DESCRIP,DEEP_IND,DEEP_POSITIONS,CALCULATE_LOC_HEIGHTS_FLAG) 
    values ('MXI','MATRIX INDUCTION SLOT','N',1,'N'); 
    
INSERT into slot_type (SLOT_TYPE,DESCRIP,DEEP_IND,DEEP_POSITIONS,CALCULATE_LOC_HEIGHTS_FLAG) 
    values ('MXT','MATRIX STAGING SLOT','N',1,'N'); 

INSERT into slot_type (SLOT_TYPE,DESCRIP,DEEP_IND,DEEP_POSITIONS,CALCULATE_LOC_HEIGHTS_FLAG) 
    values ('MXC','MATRIX CAUSTIC SLOT','N',1,'N'); 

INSERT into slot_type (SLOT_TYPE,DESCRIP,DEEP_IND,DEEP_POSITIONS,CALCULATE_LOC_HEIGHTS_FLAG) 
    values ('MXF','MATRIX FOOD/NONFOOD SLOT','N',1,'N'); 

INSERT into slot_type (SLOT_TYPE,DESCRIP,DEEP_IND,DEEP_POSITIONS,CALCULATE_LOC_HEIGHTS_FLAG) 
    values ('MXS','MATRIX SPUR SLOT','N',1,'N'); 

INSERT into slot_type (SLOT_TYPE,DESCRIP,DEEP_IND,DEEP_POSITIONS,CALCULATE_LOC_HEIGHTS_FLAG) 
    values ('MXO','MATRIX OUTBOUND SLOT','N',1,'N'); 

-------UPDATE STATEMENT FOR THE SLOT_TYPE------

UPDATE slot_type SET calculate_loc_heights_flag ='N' WHERE slot_type = 'MLS';

-----INSERT LZONE

INSERT INTO LZONE (LOGI_LOC,ZONE_ID) VALUES ('LX1111','LXPUT');
INSERT INTO LZONE (LOGI_LOC,ZONE_ID) VALUES ('LX1111','LXPKD');

INSERT INTO LZONE (LOGI_LOC,ZONE_ID) VALUES ('LX2222','LXPUT');
INSERT INTO LZONE (LOGI_LOC,ZONE_ID) VALUES ('LX2222','LXPKD');

INSERT INTO LZONE (LOGI_LOC,ZONE_ID) VALUES ('LX3333','LXPUT');
INSERT INTO LZONE (LOGI_LOC,ZONE_ID) VALUES ('LX3333','LXPKD');

INSERT INTO LZONE (LOGI_LOC,ZONE_ID) VALUES ('LX4444','LXPUT');
INSERT INTO LZONE (LOGI_LOC,ZONE_ID) VALUES ('LX4444','LXPKD');

INSERT INTO LZONE (LOGI_LOC,ZONE_ID) VALUES ('LX5555','LXPUT');
INSERT INTO LZONE (LOGI_LOC,ZONE_ID) VALUES ('LX5555','LXPKD');

INSERT INTO LZONE (LOGI_LOC,ZONE_ID) VALUES ('LX6666','LXPUT');
INSERT INTO LZONE (LOGI_LOC,ZONE_ID) VALUES ('LX6666','LXPKD');

INSERT INTO LZONE (LOGI_LOC,ZONE_ID) VALUES ('LX7777','LXPUT');
INSERT INTO LZONE (LOGI_LOC,ZONE_ID) VALUES ('LX7777','LXPKD'); 

INSERT INTO LZONE (LOGI_LOC,ZONE_ID) VALUES ('LX9999','LXPUT');
INSERT INTO LZONE (LOGI_LOC,ZONE_ID) VALUES ('LX9999','LXPKD');

INSERT INTO LZONE (LOGI_LOC,ZONE_ID) VALUES ('LX01D1','LXPKD');
INSERT INTO LZONE (LOGI_LOC,ZONE_ID) VALUES ('LX01D1','LXPUT');

INSERT INTO LZONE (LOGI_LOC,ZONE_ID) VALUES ('LX01C1','LXPKC');
INSERT INTO LZONE (LOGI_LOC,ZONE_ID) VALUES ('LX01C1','LXPUT');

INSERT INTO LZONE (LOGI_LOC,ZONE_ID) VALUES ('LX00R9','LXPUT');
INSERT INTO LZONE (LOGI_LOC,ZONE_ID) VALUES ('LX00R9','LXPKD');


-- Thu Sep 18 12:42:33 CDT 2014  Brian Bent -- Why do we have 2 pick zones entries for the spur locations ???
INSERT INTO LZONE (LOGI_LOC,ZONE_ID) VALUES ('SP01A1','LXPUT');
INSERT INTO LZONE (LOGI_LOC,ZONE_ID) VALUES ('SP01A1','LXPKD');
INSERT INTO LZONE (LOGI_LOC,ZONE_ID) VALUES ('SP01A1','LXPKC');

INSERT INTO LZONE (LOGI_LOC,ZONE_ID) VALUES ('SP02A1','LXPUT');
INSERT INTO LZONE (LOGI_LOC,ZONE_ID) VALUES ('SP02A1','LXPKD');
INSERT INTO LZONE (LOGI_LOC,ZONE_ID) VALUES ('SP02A1','LXPKC');

INSERT INTO LZONE (LOGI_LOC,ZONE_ID) VALUES ('SP03A1','LXPUT');
INSERT INTO LZONE (LOGI_LOC,ZONE_ID) VALUES ('SP03A1','LXPKD');
INSERT INTO LZONE (LOGI_LOC,ZONE_ID) VALUES ('SP03A1','LXPKC');

INSERT INTO LZONE (LOGI_LOC,ZONE_ID) VALUES ('SP04A1','LXPUT');
INSERT INTO LZONE (LOGI_LOC,ZONE_ID) VALUES ('SP04A1','LXPKD');
INSERT INTO LZONE (LOGI_LOC,ZONE_ID) VALUES ('SP04A1','LXPKC');

INSERT INTO LZONE (LOGI_LOC,ZONE_ID) VALUES ('SP05A1','LXPUT');
INSERT INTO LZONE (LOGI_LOC,ZONE_ID) VALUES ('SP05A1','LXPKD');
INSERT INTO LZONE (LOGI_LOC,ZONE_ID) VALUES ('SP05A1','LXPKC');

INSERT INTO LZONE (LOGI_LOC,ZONE_ID) VALUES ('SP06A1','LXPUT');
INSERT INTO LZONE (LOGI_LOC,ZONE_ID) VALUES ('SP06A1','LXPKD');
INSERT INTO LZONE (LOGI_LOC,ZONE_ID) VALUES ('SP06A1','LXPKC');

INSERT INTO LZONE (LOGI_LOC,ZONE_ID) VALUES ('SP07J1','LXPUT');
INSERT INTO LZONE (LOGI_LOC,ZONE_ID) VALUES ('SP07J1','LXPKD');
INSERT INTO LZONE (LOGI_LOC,ZONE_ID) VALUES ('SP07J1','LXPKC');

--------INSERT STATEMENT FOR THE LOC----------

INSERT into LOC
     (LOGI_LOC, STATUS, PALLET_TYPE, PERM, 
      PIK_AISLE,PIK_SLOT, PIK_LEVEL,  PIK_PATH, 
      PUT_AISLE,PUT_SLOT, PUT_LEVEL,  PUT_PATH,     CUBE,     
     DESCRIP,SLOT_TYPE,AISLE_SIDE,RACK_LABEL_TYPE ,ADD_DATE ,ADD_USER)
VALUES 
    ( 'LX1111','AVL','LW','N',
      999, 999, 999, 999999999,
      999, 999, 999, 999999999, 9999,
      'MX INDUCTION LOCATION','MXI','E','H',SYSDATE,USER);

INSERT into LOC
     (LOGI_LOC, STATUS, PALLET_TYPE, PERM, 
      PIK_AISLE,PIK_SLOT, PIK_LEVEL,  PIK_PATH, 
      PUT_AISLE,PUT_SLOT, PUT_LEVEL,  PUT_PATH,     CUBE,     
     DESCRIP,SLOT_TYPE,AISLE_SIDE,RACK_LABEL_TYPE ,ADD_DATE ,ADD_USER)
VALUES 
    ( 'LX2222','AVL','LW','N',
      999, 999, 999, 999999999,
      999, 999, 999, 999999999, 9999,
      'MX STAGE LOCATION','MXT','E','H',SYSDATE,USER);

INSERT into LOC
     (LOGI_LOC, STATUS, PALLET_TYPE, PERM, 
      PIK_AISLE,PIK_SLOT, PIK_LEVEL,  PIK_PATH, 
      PUT_AISLE,PUT_SLOT, PUT_LEVEL,  PUT_PATH,     CUBE,     
     DESCRIP,SLOT_TYPE,AISLE_SIDE,RACK_LABEL_TYPE ,ADD_DATE ,ADD_USER)
VALUES 
    ( 'LX3333','AVL','LW','N',
      999, 999, 999, 999999999,
      999, 999, 999, 999999999, 9999,
      'MX STAGE LOCATION','MXT','E','H',SYSDATE,USER);
      
INSERT into LOC
     (LOGI_LOC, STATUS, PALLET_TYPE, PERM, 
      PIK_AISLE,PIK_SLOT, PIK_LEVEL,  PIK_PATH, 
      PUT_AISLE,PUT_SLOT, PUT_LEVEL,  PUT_PATH,     CUBE,     
     DESCRIP,SLOT_TYPE,AISLE_SIDE,RACK_LABEL_TYPE ,ADD_DATE ,ADD_USER)
VALUES 
    ( 'LX4444','AVL','LW','N',
      999, 999, 999, 999999999,
      999, 999, 999, 999999999, 9999,
      'MX STAGE LOCATION','MXT','E','H',SYSDATE,USER);
      
INSERT into LOC
     (LOGI_LOC, STATUS, PALLET_TYPE, PERM, 
      PIK_AISLE,PIK_SLOT, PIK_LEVEL,  PIK_PATH, 
      PUT_AISLE,PUT_SLOT, PUT_LEVEL,  PUT_PATH,     CUBE,     
     DESCRIP,SLOT_TYPE,AISLE_SIDE,RACK_LABEL_TYPE ,ADD_DATE ,ADD_USER)
VALUES 
    ( 'LX5555','AVL','LW','N',
      999, 999, 999, 999999999,
      999, 999, 999, 999999999, 9999,
      'MX STAGE LOCATION','MXT','E','H',SYSDATE,USER);
      
      
INSERT into LOC
     (LOGI_LOC, STATUS, PALLET_TYPE, PERM, 
      PIK_AISLE,PIK_SLOT, PIK_LEVEL,  PIK_PATH, 
      PUT_AISLE,PUT_SLOT, PUT_LEVEL,  PUT_PATH,     CUBE,     
     DESCRIP,SLOT_TYPE,AISLE_SIDE,RACK_LABEL_TYPE ,ADD_DATE ,ADD_USER)
VALUES 
    ( 'LX6666','AVL','LW','N',
      999, 999, 999, 999999999,
      999, 999, 999, 999999999, 9999,
      'MX STAGE LOCATION','MXT','E','H',SYSDATE,USER);
      
      
INSERT into LOC
     (LOGI_LOC, STATUS, PALLET_TYPE, PERM, 
      PIK_AISLE,PIK_SLOT, PIK_LEVEL,  PIK_PATH, 
      PUT_AISLE,PUT_SLOT, PUT_LEVEL,  PUT_PATH,     CUBE,     
     DESCRIP,SLOT_TYPE,AISLE_SIDE,RACK_LABEL_TYPE ,ADD_DATE ,ADD_USER)
VALUES 
    ( 'LX7777','AVL','LW','N',
      999, 999, 999, 999999999,
      999, 999, 999, 999999999, 9999,
      'MX STAGE LOCATION','MXT','E','H',SYSDATE,USER);

INSERT into LOC
     (LOGI_LOC, STATUS, PALLET_TYPE, PERM, 
      PIK_AISLE,PIK_SLOT, PIK_LEVEL,  PIK_PATH, 
      PUT_AISLE,PUT_SLOT, PUT_LEVEL,  PUT_PATH,     CUBE,     
     DESCRIP,SLOT_TYPE,AISLE_SIDE,RACK_LABEL_TYPE ,ADD_DATE ,ADD_USER)
VALUES 
    ( 'LX9999','AVL','LW','N',
      999, 999, 999, 999999999,
      999, 999, 999, 999999999, 9999,
      'MX OUTDUCT LOCATION','MXO','E','H',SYSDATE,USER);

INSERT into LOC
     (LOGI_LOC,     STATUS,     PALLET_TYPE,    PERM, PIK_AISLE,     PIK_SLOT,     PIK_LEVEL,    PIK_PATH, PUT_AISLE,     PUT_SLOT, PUT_LEVEL,  PUT_PATH,     CUBE,     
     DESCRIP,SLOT_TYPE,AISLE_SIDE,RACK_LABEL_TYPE ,ADD_DATE ,ADD_USER)
VALUES 
    ( 'LX01D1','AVL','LW','N',999,999,999, 999,999,999,999,999999999,999,'MX INV FOOD TYPE','MXF','E','H',SYSDATE,USER);

INSERT into LOC
     (LOGI_LOC,     STATUS,     PALLET_TYPE,    PERM, PIK_AISLE,     PIK_SLOT,     PIK_LEVEL,    PIK_PATH, PUT_AISLE,     PUT_SLOT, PUT_LEVEL,  PUT_PATH,     CUBE,     
     DESCRIP,SLOT_TYPE,AISLE_SIDE,RACK_LABEL_TYPE ,ADD_DATE ,ADD_USER)
VALUES 
    ( 'LX01C1','AVL','LW','N',999,999,999, 999,999,999,999,999999999,999,'MX INV CAUSTIC','MXC','E','H',SYSDATE,USER);

INSERT into LOC
     (LOGI_LOC,     STATUS,     PALLET_TYPE,    PERM, PIK_AISLE,     PIK_SLOT,     PIK_LEVEL,    PIK_PATH, PUT_AISLE,     PUT_SLOT, PUT_LEVEL,  PUT_PATH,     CUBE,     
     DESCRIP,SLOT_TYPE,AISLE_SIDE,RACK_LABEL_TYPE ,ADD_DATE ,ADD_USER)
VALUES 
    ( 'SP01A1','AVL','LW','N',999,999,999, 999,999,999,999,999999999,999,'MX SPUR 1','MXS','E','H',SYSDATE,USER);

INSERT into LOC
     (LOGI_LOC,     STATUS,     PALLET_TYPE,    PERM, PIK_AISLE,     PIK_SLOT,     PIK_LEVEL,    PIK_PATH, PUT_AISLE,     PUT_SLOT, PUT_LEVEL,  PUT_PATH,     CUBE,     
     DESCRIP,SLOT_TYPE,AISLE_SIDE,RACK_LABEL_TYPE ,ADD_DATE ,ADD_USER)
VALUES 
    ( 'SP02A1','AVL','LW','N',999,999,999, 999,999,999,999,999999999,999,'MX SPUR 2','MXS','E','H',SYSDATE,USER);

INSERT into LOC
     (LOGI_LOC,     STATUS,     PALLET_TYPE,    PERM, PIK_AISLE,     PIK_SLOT,     PIK_LEVEL,    PIK_PATH, PUT_AISLE,     PUT_SLOT, PUT_LEVEL,  PUT_PATH,     CUBE,     
     DESCRIP,SLOT_TYPE,AISLE_SIDE,RACK_LABEL_TYPE ,ADD_DATE ,ADD_USER)
VALUES 
    ( 'SP03A1','AVL','LW','N',999,999,999, 999,999,999,999,999999999,999,'MX SPUR 3','MXS','E','H',SYSDATE,USER);

INSERT into LOC
     (LOGI_LOC,     STATUS,     PALLET_TYPE,    PERM, PIK_AISLE,     PIK_SLOT,     PIK_LEVEL,    PIK_PATH, PUT_AISLE,     PUT_SLOT, PUT_LEVEL,  PUT_PATH,     CUBE,     
     DESCRIP,SLOT_TYPE,AISLE_SIDE,RACK_LABEL_TYPE ,ADD_DATE ,ADD_USER)
VALUES 
    ( 'SP04A1','AVL','LW','N',999,999,999, 999,999,999,999,999999999,999,'MX SPUR 4','MXS','E','H',SYSDATE,USER);

INSERT into LOC
     (LOGI_LOC,     STATUS,     PALLET_TYPE,    PERM, PIK_AISLE,     PIK_SLOT,     PIK_LEVEL,    PIK_PATH, PUT_AISLE,     PUT_SLOT, PUT_LEVEL,  PUT_PATH,     CUBE,     
     DESCRIP,SLOT_TYPE,AISLE_SIDE,RACK_LABEL_TYPE ,ADD_DATE ,ADD_USER)
VALUES 
    ( 'SP05A1','AVL','LW','N',999,999,999, 999,999,999,999,999999999,999,'MX SPUR 5','MXS','E','H',SYSDATE,USER);

INSERT into LOC
     (LOGI_LOC,     STATUS,     PALLET_TYPE,    PERM, PIK_AISLE,     PIK_SLOT,     PIK_LEVEL,    PIK_PATH, PUT_AISLE,     PUT_SLOT, PUT_LEVEL,  PUT_PATH,     CUBE,     
     DESCRIP,SLOT_TYPE,AISLE_SIDE,RACK_LABEL_TYPE ,ADD_DATE ,ADD_USER)
VALUES 
    ( 'SP06A1','AVL','LW','N',999,999,999, 999,999,999,999,999999999,999,'MX SPUR 6','MXS','E','H',SYSDATE,USER);

INSERT into LOC
     (LOGI_LOC, STATUS, PALLET_TYPE, PERM, 
      PIK_AISLE,PIK_SLOT, PIK_LEVEL,  PIK_PATH, 
      PUT_AISLE,PUT_SLOT, PUT_LEVEL,  PUT_PATH,     CUBE,     
     DESCRIP,SLOT_TYPE,AISLE_SIDE,RACK_LABEL_TYPE ,ADD_DATE ,ADD_USER)
VALUES 
    ( 'SP07J1','AVL','LW','N',
      999, 999, 999, 999999999,
      999, 999, 999, 999999999, 9999,
      'MX JACKPOT LANE','MXS','E','H',SYSDATE,USER);


--- AISEL_INFO TABLE
INSERT into AISLE_INFO
(PICK_AISLE,NAME,DIRECTION,DIRECTED,SUB_AREA_CODE)
VALUES
(999,       'LX', 0       , 'Y'    , 'D'         );

INSERT into AISLE_INFO
(PICK_AISLE,NAME,DIRECTION,DIRECTED,SUB_AREA_CODE)
VALUES
(998,       'SP', 0       , 'Y'    , 'D'         );

