USE UAT
Create Table tblProductsSale
(
   Id int primary key,
   SalesAgent nvarchar(50),
   SalesCountry nvarchar(50),
   SalesAmount int
)

Insert into tblProductsSale values(1, 'Tom', 'UK', 200)
Insert into tblProductsSale values(2, 'John', 'US', 180)
Insert into tblProductsSale values(3, 'John', 'UK', 260)
Insert into tblProductsSale values(4, 'David', 'India', 450)
Insert into tblProductsSale values(5, 'Tom', 'India', 350)
Insert into tblProductsSale values(6, 'David', 'US', 200)
Insert into tblProductsSale values(7, 'Tom', 'US', 130)
Insert into tblProductsSale values(8, 'John', 'India', 540)
Insert into tblProductsSale values(9, 'John', 'UK', 120)
Insert into tblProductsSale values(10, 'David', 'UK', 220)
Insert into tblProductsSale values(11, 'John', 'UK', 420)
Insert into tblProductsSale values(12, 'David', 'US', 320)
Insert into tblProductsSale values(13, 'Tom', 'US', 340)
Insert into tblProductsSale values(14, 'Tom', 'UK', 660)
Insert into tblProductsSale values(15, 'John', 'India', 430)
Insert into tblProductsSale values(16, 'David', 'India', 230)
Insert into tblProductsSale values(17, 'David', 'India', 280)
Insert into tblProductsSale values(18, 'Tom', 'UK', 480)
Insert into tblProductsSale values(19, 'John', 'US', 360)
Insert into tblProductsSale values(20, 'David', 'UK', 140)


select SalesAgent,SalesCountry,count(*) as total from tblProductsSale
group by SalesAgent,SalesCountry
order by SalesAgent,SalesCountry


Select SalesAgent, India, US, UK
from tblProductsSale
Pivot
(
   Sum(SalesAmount) for SalesCountry in ([India],[US],[UK])
)
as PivotTable


Create Table tblProductsSales
(
   Id int primary key,
   SalesAgent nvarchar(50),
   SalesCountry nvarchar(50),
   SalesAmount int
)

Insert into tblProductsSales values(1, 'Tom', 'UK', 200)
Insert into tblProductsSales values(2, 'John', 'US', 180)
Insert into tblProductsSales values(3, 'John', 'UK', 260)
Insert into tblProductsSales values(4, 'David', 'India', 450)
Insert into tblProductsSales values(5, 'Tom', 'India', 350)
Insert into tblProductsSales values(6, 'David', 'US', 200)
Insert into tblProductsSales values(7, 'Tom', 'US', 130)
Insert into tblProductsSales values(8, 'John', 'India', 540)
Insert into tblProductsSales values(9, 'John', 'UK', 120)
Insert into tblProductsSales values(10, 'David', 'UK', 220)
Insert into tblProductsSales values(11, 'John', 'UK', 420)
Insert into tblProductsSales values(12, 'David', 'US', 320)
Insert into tblProductsSales values(13, 'Tom', 'US', 340)
Insert into tblProductsSales values(14, 'Tom', 'UK', 660)
Insert into tblProductsSales values(15, 'John', 'India', 430)
Insert into tblProductsSales values(16, 'David', 'India', 230)
Insert into tblProductsSales values(17, 'David', 'India', 280)
Insert into tblProductsSales values(18, 'Tom', 'UK', 480)
Insert into tblProductsSales values(19, 'John', 'US', 360)
Insert into tblProductsSales values(20, 'David', 'UK', 140)

Select  SalesAgent,india,US,UK from tblProductsSales
pivot
(
	sum(SalesAmount) for SalesCountry in ([india],[US],[UK])
) as pivottable

Select SalesAgent,India,US,UK
from 
(
	Select SalesAgent,SalesCountry,SalesAmount from tblProductsSales
)
as SourcetblProductsSales
pivot
(
	sum(SalesAmount) for SalesCountry in([India],[US],[UK])
) as pivottable