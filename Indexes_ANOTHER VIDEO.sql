use UAT

CREATE INDEX IX_TBLEMPLOYEE_SALARY
ON tblEmployee (SALARY ASC)

SP_HELPINDEX tblEmployee

SELECT * FROM tblEmployee WHERE SALARY > '700'

DROP INDEX TBL_EMPLOYEE.IX_TBLEMPLOYEE_SALARY
