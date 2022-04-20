--liquibase formatted sql

--changeset AUTHOR:wimukthi
--comment create table test_table
CREATE TABLE SWMS.test_table
(
  id INT NOT NULL,
  name VARCHAR(255) NOT NULL,
  PRIMARY KEY (id)
);
