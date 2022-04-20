-- Charm6000003306 - To Restrict more than one user to login One Equipment.
ALTER TABLE equip
 ADD( user_id varchar2(30 byte), update_date date default sysdate);
