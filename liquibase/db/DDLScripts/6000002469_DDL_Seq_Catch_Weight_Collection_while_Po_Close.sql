--CHARM#6000002469-Sequencing catch weight collection while closing a PO
alter table tmp_weight drop constraint pk_prodid;
alter table tmp_weight add constraint pk_prodid primary key (erm_id,prod_id,cust_pref_vendor);