ALTER TYPE SWMS."STS_ROUTE_OUT_OBJECT" DROP ATTRIBUTE (ROUTE_DATE, SCHED_ARRIV_TIME, SCHED_DEPT_TIME, STOP_OPEN_TIME, STOP_CLOSE_TIME, DELIVERY_WINDOW_START, DELIVERY_WINDOW_END, DUE_DATE) CASCADE
/

ALTER TYPE SWMS."STS_ROUTE_OUT_OBJECT" ADD ATTRIBUTE (ROUTE_DATE VARCHAR2(19), SCHED_ARRIV_TIME VARCHAR2(19), SCHED_DEPT_TIME VARCHAR2(19), STOP_OPEN_TIME VARCHAR2(19), STOP_CLOSE_TIME VARCHAR2(19), DELIVERY_WINDOW_START VARCHAR2(19), DELIVERY_WINDOW_END VARCHAR2(19), DUE_DATE VARCHAR2(19)) CASCADE
/
