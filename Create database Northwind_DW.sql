

-----------------------------------Create database Northwind_DW--------------------------------------------------------------------------------------



Use master
go


IF EXISTS(select * from sys.databases where name='Northwind_DW')
DROP DATABASE Northwind_DW
go

Create database Northwind_DW
go

Use Northwind_DW
go

create procedure usp_NorthwindDW
as
go

create function fn_zero(@unitprice money)
returns int
as
begin
if @unitprice is null
set @unitprice=0
return @unitprice
end

go

create function fn_categoryName(@categoryID int)
returns nvarchar(15)
as
	begin
		declare @CatName as nvarchar(15)
		set @catName=(select CategoryName from NORTHWND.dbo.Categories where CategoryID=1)
		return @catName
	end
go

create function fn_supplierName(@supplierID int)
returns nvarchar(40)
as
	begin
		declare @supName as nvarchar(40)
		set @supName=(select Companyname from NORTHWND.dbo.suppliers where supplierID=@supplierID)
		return @supname
	end
go

create function fn_ProducyType(@unitPrice money)
returns nvarchar(20)
as
begin
	declare @productType nvarchar(20),@avgUnitPrice int
	set @avgunitprice=(select avg(unitprice) from NORTHWND.dbo.Products)
	if @unitprice>@avgunitprice
		set @producttype='expensive'
	else
		set @producttype='cheap'

return @producttype
end
go

create function fn_age(@birthDate datetime)
returns int
as
	begin
		declare @age int 
		set @age=DATEDIFF(year,@birthDate,getdate()) 
		return @age
	end
go

create function fn_reportsTo(@reportsTo int)
returns nvarchar(30)
as
	begin
		declare @repTo nvarchar(30)
		if @reportsTo is null
			set @repTo=(select FirstName+' '+lastname from NORTHWND.dbo.Employees where ReportsTo is null)
		else
			set @repTo=(select FirstName+' '+lastname from NORTHWND.dbo.Employees where EmployeeID=@reportsTo)
		return @repTo
	end
go

create function fn_Dates()
returns @T_dim_dates table ([DateSK] [int] PRIMARY KEY NOT NULL,
						  [Date] [date] NOT NULL,
						  [Year] int,
						  [Quarter] int,
						  [Month] int,
						  [MonthName] nvarchar(20))
as
begin
		declare @DatesNum int,@DateSk int, @Date date,@Year int,@Qarter int,@Month int,@Monthname nvarchar(20)
		set @Date=convert(date,'1996-01-01')
		set @DatesNum=datediff(d,@date,'1999-12-31')
			
			while @DatesNum >= 0
			begin
					set @DateSk=convert(int,(convert(nvarchar(4),datepart(YYYY,@Date))+substring(convert(nvarchar(10),@Date),6,2)+substring(convert(nvarchar(10),@Date),9,2)))
					set @Year=datepart(YYYY,@Date)
					set @Qarter=datepart(QUARTER,@Date)
					set @Month=datepart(month,@Date)
					set @Monthname=datename(M,@Date)
					insert into @T_dim_dates
					values (@dateSk,@Date,@Year,@Qarter,@Month,@Monthname)

				set @Date=dateadd(d,1,@date)
				set @DatesNum=@DatesNum-1
			end
return
end

go

create function fn_unknown (@column nvarchar(40))
returns nvarchar(40)
as
begin
if @column is null
	set @column='Unknown'
return @column
end
go

create function fn_unwnDates(@Date date)
returns date
as
begin
if @Date is null 
set @Date='1990-01-01'
return @date
end
go

create function fn_FSales()
returns @T_FSales table (
						[OrderSK] [int] NOT NULL,
						[ProductSK] [int] NOT NULL,
						[DateKey] [int] NOT NULL,
						[DateKeyShipped] [int] NULL,
						[CustomerSK] [int] NOT NULL,
						[EmployeeSK] [int] NOT NULL,
						[UnitPrice] [money] NOT NULL,
						[Quantity] [smallint] NOT NULL,
						[Discount] [real] NOT NULL)
as
begin

declare @ord_bk int ,@Ord_SK int ,@Prd_SK int,@prd_id int,@Dat_SK int,@Dateship int,@cust_SK int,@emp_SK int,@unitP money,@quantity smallint,@discount real,
@NumofOrders int,@i int,@j int 
set @NumofOrders=(select count(*) from Dim_Orders)
set @i=1

while @i <= @NumofOrders
begin
		set @ord_bk=(select Orderbk from (select OrderBK, ROW_NUMBER() over(order by ordersk) as [ROW] from Dim_Orders) as O where [row]=@i)
		set @Ord_SK=(select OrderSK from Dim_Orders where OrderBK=@ord_bk)
		set @cust_SK=(select CustomerSK from Dim_Customers where CustomerBK=(select CustomerID
																				from NORTHWND.dbo.Orders
																				where OrderID=@ord_bk))

		set @emp_SK=(select EmployeeSK from Dim_Employees where EmployeeBK=(select EmployeeID
																				from NORTHWND.dbo.Orders
																				where OrderID=@ord_bk))

		
		if (select shippeddate from NORTHWND.dbo.Orders where OrderID=@ord_bk) is null
			begin
				set @Dat_SK=19900101
				set @Dateship=null
			end
		else
			begin
			set @Dat_SK=(select DateSK from Dim_Dates where [Date]=(select shippeddate from NORTHWND.dbo.Orders where OrderID=@ord_bk))
			set @Dateship=@Dat_SK
			end
		set @j=(select count(*) from NORTHWND.dbo.[Order Details] where OrderID=@ord_bk)
		declare @k int
		set @k=1
			while @k<=@j
			begin
			select @unitP=unitprice ,@quantity=Quantity,@discount=discount, @prd_id=productid from (select productid,UnitPrice,Quantity,Discount,ROW_NUMBER() over(order by orderid,productid) as [ROW2]
								from NORTHWND.dbo.[Order Details] where OrderID=@ord_bk) op where ROW2=@k
			set @Prd_SK=(select ProductSK  from Dim_Products where ProductBK=@prd_id)
			if @Dateship is null
			set @Dateship=19900101
			insert into @T_FSales
			values (@Ord_SK,@Prd_SK,@Dat_SK,@Dateship,@cust_SK,@emp_SK,@unitP,@quantity,@discount)
			set @k=@k+1
			end

	set @i=@i+1
end
return
end

go

if exists (select * from sys.tables where name ='dbo.dim_products')
drop table dbo.dim_products

CREATE TABLE [dbo].[Dim_Products](
	[ProductSK] [int] identity(100,1) PRIMARY KEY NOT NULL,
	[ProductBK] [int] NOT NULL,
	[ProductName] [nvarchar](40) NOT NULL,
	[ProductUnitPrice] [money] NULL,
	ProductType nvarchar(20),
	[CategoryName] [nvarchar](15) NOT NULL,
	[SupplierName] [nvarchar](40) NOT NULL,
	[Discontinued] [bit] NOT NULL
)

insert into [dbo].[Dim_Products] (ProductBK,ProductName,ProductUnitPrice,ProductType,CategoryName,SupplierName,Discontinued)
select ProductID,ProductName,dbo.fn_zero(UnitPrice),dbo.fn_ProducyType(UnitPrice),dbo.fn_categoryname(CategoryID),dbo.fn_suppliername(SupplierID),Discontinued
from NORTHWND.dbo.Products

if exists (select * from sys.tables where name ='dbo.dim_employees')
drop table dbo.Dim_Employees

CREATE TABLE [dbo].[Dim_Employees](
	[EmployeeSK] [int] identity(100,1) PRIMARY KEY NOT NULL,
	[EmployeeBK] [int] NOT NULL,
	[LastName] [nvarchar](20) NOT NULL,
	[FirstName] [nvarchar](10) NOT NULL,
	[FullName] [nvarchar](32) NOT NULL,
	[Title] [nvarchar](30) NULL,
	[BirthDate] [datetime] NULL,
	Age int null,
	[HireDate] [datetime] NULL,
	Seniority int null,
	[City] [nvarchar](15) NULL,
	[Country] [nvarchar](15) NULL,
	[Photo] [image] NULL,
	[ReportsTo] [nvarchar](30) NULL
)

insert into [dbo].[Dim_Employees] (EmployeeBK,LastName,FirstName,FullName,Title,BirthDate,Age,HireDate,Seniority,City,Country,Photo,ReportsTo)
select EmployeeID,LastName,FirstName,FirstName+' '+LastName,dbo.fn_unknown(Title),dbo.fn_unwnDates(BirthDate),dbo.fn_age(birthdate),dbo.fn_unwnDates(HireDate),
dbo.fn_age(HireDate),dbo.fn_unknown(city),dbo.fn_unknown(Country),Photo,dbo.fn_reportsTo(ReportsTo)
from NORTHWND.dbo.Employees

if exists (select * from sys.tables where name ='dbo.dim_customers')
drop table dbo.dim_customers

CREATE TABLE [dbo].[Dim_Customers](
	[CustomerSK] int identity(100,1) PRIMARY KEY NOT NULL,
	[CustomerBK] [nchar](5) NOT NULL,
	[CustomerName] [nvarchar](40) NOT NULL,
	[City] [nvarchar](15) NULL,
	[Region] [nvarchar](15) NULL,
	[Country] [nvarchar](15) NULL
)

insert into [dbo].[Dim_Customers] 
select CustomerID,CompanyName,dbo.fn_unknown(city),dbo.fn_unknown(region),dbo.fn_unknown(Country)
from NORTHWND.dbo.Customers

if exists (select * from sys.tables where name ='dbo.dim_orders')
drop table dbo.Dim_Orders

CREATE TABLE [dbo].[Dim_Orders](
	[OrderSK] [int] identity(100,1) PRIMARY KEY NOT NULL,
	[OrderBK] [int] NOT NULL,
	[ShipCity] [nvarchar](15) NULL,
	[ShipRegion] [nvarchar](15) NULL,
	[ShipCountry] [nvarchar](15) NULL
 )
 
 insert into [Dim_Orders]
 select OrderID,dbo.fn_unknown(ShipCity),dbo.fn_unknown(ShipRegion),dbo.fn_unknown(ShipCountry)
 from NORTHWND.dbo.Orders

 if exists (select * from sys.tables where name ='dbo.dim_dates')
drop table dbo.Dim_Dates

create TABLE [dbo].[Dim_Dates]([DateSK] [int],
							   [Date] [datetime] NOT NULL,
							   [Year] int,
							   [Quarter] int,
							   [Month] int,
							   [MonthName] nvarchar(20))

insert into [dbo].[Dim_Dates]
select *
from fn_Dates()

if exists (select * from sys.tables where name ='dbo.fact_sales')
drop table dbo.Fact_Sales

 CREATE TABLE [dbo].[Fact_Sales](
	SalesSK int identity(100,1) PRIMARY KEY not null,
	[OrderSK] [int] NOT NULL,
	[ProductSK] [int] NOT NULL,
	[DateKey] [int] NOT NULL,
	[DateKeyShipped] [int] NULL,
	[CustomerSK] [int] NOT NULL,
	[EmployeeSK] [int] NOT NULL,
	[UnitPrice] [money] NOT NULL,
	[Quantity] [smallint] NOT NULL,
	[Discount] [real] NOT NULL
)

insert into [dbo].[Fact_Sales]
select *
from fn_FSales()


execute usp_NorthwindDW

