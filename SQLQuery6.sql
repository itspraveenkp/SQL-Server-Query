USE [LAKSHYA]
GO
/****** Object:  StoredProcedure [cdgmaster].[usp_PF_secondary_Dist_Refetch]    Script Date: 8/6/2020 5:13:17 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--v20180604

ALTER Procedure [cdgmaster].[usp_PF_secondary_Dist_Refetch]  
(   @dBug INT=0
--  @PdistCode VARCHAR(50),
--  @Src INT=0 -- 0:both, 1:DS, 2:SR
)  
/*    
	EXEC cdgmASter.usp_PF_secondary_Dist_Refetch 1
	20130521 Pavitar Procedure to re-fetch a distributor at a time from console 
	20130610 Pavitar Loop for unprocessed Requests in Re-runLogs
	20130619 Pavitar Do not check active/inactive for distributors
	20130625 Pavitar Update LP,PTR for MRP=0
	20140123 Kavita Insert current month-yr in runMM-runYr in tblpf_secsalesM
					isnull check for NR, if NR is null then insert zero
*/    
  
AS    
BEGIN --{    
  
 
SET nocount ON    
  
SET xact_abort ON  

     
DECLARE @procMon INT, @procYr INT  
  , @recFound CHAR(1), @wkStr VARCHAR(10)
  , @wkStrTemp VARCHAR(10)    
  , @WaveCnt INT
  
SET @WaveCnt =0
--SELECT @prevRunDt = '', @recFound= 'N', @procMon = -1, @maxToDate = dateAdd(d, -1, getDate())  
SELECT @recFound= 'N', @procMon = -1
  
DECLARE @loopNeeded CHAR(1)  
, @distCode VARCHAR(50)  
, @stateCode INT  
, @recCnt bigINT  
, @lAStMsgId INT  
, @lAStCtrlId INT  
  
CREATE TABLE #tempDist (    
  distCode VARCHAR(50)  
, stateCode INT  
)    
  
CREATE TABLE #TempDS(   
 serNo INT IDENTITY(1,1),  
 mon INT,  
 yr INT,  
 wk INT,  
 wkstr VARCHAR(50),  
 distcode VARCHAR(50),   
 prdcode  VARCHAR(50), 
 NR NUMERIC(16, 3),    
 dsMRP FLOAT,
 prdgrossamt NUMERIC(16, 3),     
 prdqty NUMERIC(16, 3),      
 LP  NUMERIC(16, 3),  
 PTR NUMERIC(16, 3),  
 salInvDate DATETIME, 
 errNR VARCHAR(50),
 charidx INT,
 errPTR VARCHAR(50),
 CHARidxPTR INT,	  
 errLP VARCHAR(50), 
 CHARidxLP INT,	  
 isErrYN CHAR(1) DEFAULT 'N',  
 SRC VARCHAR(2),
 CreatedDate DATETIME
) 

CREATE INDEX idx_#TempDS ON #TempDS
(	
	dsMRP desc,
	isErrYN 
)

CREATE TABLE #TempDailySales(   
 serNo INT IDENTITY(1,1),  
 mon INT,  
 yr INT,  
 wk INT,  
 wkstr VARCHAR(50),  
 -- tranDt DATETIME, don't use this  
 distcode VARCHAR(50),   
 prdcode  VARCHAR(50),   
 NR NUMERIC(16, 3),    
 prdgrossamt NUMERIC(16, 3),     
 prdqty NUMERIC(16, 3),    
 SRC VARCHAR(2),  
 LP  NUMERIC(16, 3),  
 PTR NUMERIC(16, 3),  
 isUPDATEM CHAR(1) DEFAULT 'N',  
 isUPDATEW CHAR(1) DEFAULT 'N',  
 recCnt INT  
, stateCode INT  
, dsMRP FLOAT  
)    
  
DECLARE @runMM INT, @runYr INT, @fDate DATETIME, @tDate DATETIME, @lastMonthEnd DATETIME
DECLARE @runMY VARCHAR(20), @indx INT, @found CHAR(1),@pDistCode  varchar(50),@recProcess Char(1),@serno BIGINT,@SRC INT
--SET @found = 'n'  
--SELECT @found = 'y', @runMY = ParamVal, @indx = charindex('-', ParamVal) FROM cdgmASter.tblSystemParam WHERE paramName = 'PFCurrYear'  
--IF @found = 'n' or @indx < 2  
--BEGIN  
--    INSERT INTO cdgmASter.tblVMRJObLog(jobCode, LogMsg) values ('RE_FETCH', 'ERROR:current Mon/yr PFCurrYear NOT FOUND/invalid in tblSystemParam. Aborting')  
--    RETURN  
--END  
--  
--SELECT @runMM = CONVERT(SMALLINT, substring(@runMY,1,@indx-1)), @runYr= CONVERT(SMALLINT, substring(@runMY,@indx+1, 4))  
SET @recProcess='N'
SELECT top 1 @recProcess='Y',@serno=serno,@runMM=pmon,@runYr=pYr,@PdistCode=pDistCode
             ,@lastMonthEnd=pLastMonthEnd,@tDate=pFetchTillDate,@src=RefetchFrom
 FROM cdgmaster.RerunLogs where JobCode='PF_SR' AND isProcessed='N' order by serno 
 
SELECT @WaveCnt = count(serno) FROM cdgmaster.RerunLogs where JobCode='PF_SR' AND isProcessed='N'

IF(@dBug>0) SELECT @runMM,@runYr,@PdistCode,@lastMonthEnd,@tDate
	WHILE @recProcess='Y'
	BEGIN--{		
		
		IF(@dBug>0)print 'Reached Here'
		
		DELETE FROM cdgmASter.tblPF_secSalesM WHERE distCode=@PdistCode AND runMM=@runMM AND runYr=@runYr
		
		INSERT INTO cdgmASter.tblPF_secSalesM_CtrlHDr ([RunDate],[OpenMON],[OpenYr])
		VALUES (getDate(),@runMM,@runYr)

		SELECT @lAStCtrlId = @@IDENTITY  

		SELECT @fDate=CONVERT(VARCHAR(10),min(salinvdate),111)
		FROM cdgmASter.businessCalENDer WHERE monthKey=@runMM and [year]=@runYr

--
--		Select @lastMonthEnd=ParamVal from cdgmaster.tblsystemParam (nolock) where paramName = 'PFMonthEndDate'
--		Select @tDate=ParamVal from cdgmaster.tblsystemParam (nolock) where paramName = 'PFSecFetch'	

		SELECT @recCnt = 0  
		--PRINT 'ok'    

		INSERT INTO cdgmASter.tblVMRjobLog (jobCode, logMsg) values ('RE_FETCH', @PdistCode +': RUN for MY:' + CAST(@runMY AS VARCHAR(11)))   
		SELECT @lAStMsgId = @@IDENTITY  

		TRUNCATE TABLE #tempDist  

		INSERT INTO #tempDist (distCode, stateCode)  
		SELECT c.SAPid, s.stateCode 
				FROM cdgmaster.customer c WITH(nolock) 
				LEFT JOIN JandJConsoleLive.dbo.UserMaster u (nolock) ON c.sapid collate SQL_Latin1_General_CP1_CI_AI=u.UserCode collate SQL_Latin1_General_CP1_CI_AI
				--LEFT JOIN JandJConsoleLive.dbo.UserMaster u (nolock) ON c.sapid =u.UserCode 
				LEFT JOIN state s (nolock) ON s.SapId=u.Others1
		   WHERE ISNULL(c.SAPid,'')=@PdistCode 

		
--20130619
--and c.isactive='y' 

			Delete from [cdgmaster].[tblPF_secSalesM_CtrlDet] where stateCode is null and HdrserNo=@lAStCtrlId
			INSERT INTO [cdgmaster].[tblPF_secSalesM_CtrlDet]([HdrserNo],[distCode],[stateCode])
				SELECT @lAStCtrlId,DistCode,stateCode FROM #tempDist WHERE stateCode is null

			DELETE FROM #tempDist WHERE stateCode is null

		SET @recFound = 'N'    
		SELECT top 1 @recFound = 'Y', @distCode= distCode, @stateCode= stateCode FROM #tempDist ORDER BY stateCode  
		WHILE @recFound = 'Y'    
		BEGIN -- {  distrib loop  
		    
			TRUNCATE TABLE #TempDS 

			IF @Src = 0	-- Daily Sales + Sales Return
			BEGIN
				  INSERT INTO #TempDS (mon, yr, wkstr,DistCode,PrdCode,SRC,dsMRP,salInvDate,prdgrossamt,prdQty,createdDate
										,NR --added column by durgesh on 03May2018 RDR 2018 001
										,LP --added column by durgesh on 16May2018 RDR 2018 001
										,PTR --added column by durgesh on 16May2018 RDR 2018 001
										)
				  SELECT cal.monthKey mon, cal.[Year] yr, cal.[Week] wkstr ,DistCode,PrdCode,'DS' SRC
				  ,ds.MRP,ds.salInvDate salInvDate
				  --,prdgrossamt,prdQty
				  ,(CASE WHEN ds.createdDate<=@lastMonTHEND AND   ds.salInvDate < @fDate THEN NULL ELSE prdgrossamt END) prdgrossamt
				  ,(CASE WHEN ds.createdDate<=@lastMonTHEND AND   ds.salInvDate < @fDate THEN NULL ELSE prdQty END) prdQty
				  ,ds.CreatedDate	
				  /*Added by durgesh on 03May2018 RDR 2018 001*/
				  ,ISNULL(ds.NRValue,0) as NR
				  ,ISNULL(ds.LPValue,0) as LP
				  ,ISNULL(ds.PrdSelRateAfterTax,0) as PTR
				  /*End*/
				  FROM JandJConsoleLive.dbo.dailysales  ds WITH(nolock)   
				  inner join cdgmASter.businessCalENDer cal ON DATEDIFF(d, ds.salinvdate, cal.salInvDate) = 0              
				  WHERE distCode = @distCode  
				  AND CONVERT(VARCHAR(20), CAST(ds.CreatedDate AS DATETIME), 111) >= CONVERT(VARCHAR(20), CAST(@fDate AS DATETIME), 111)
				  AND CONVERT(VARCHAR(20), CAST(ds.CreatedDate AS DATETIME), 111) <= CONVERT(VARCHAR(20), CAST(@tDate AS DATETIME), 111)
				 
				  UNION All
				   
				  SELECT cal.monthKey mon, cal.[Year] yr, cal.[Week] wkstr ,DistCode,PrdCode,'SR' SRC
				  ,ds.MRP,ds.srndate salInvDate
				  --,(-1 * prdgrossamt) prdgrossamt,(-1 * prdSalQty) prdQty			
				  ,(CASE WHEN ds.createdDate<=@lastMonTHEND AND   ds.SRNDATE < @fDate THEN NULL ELSE (-1 * prdgrossamt) END) prdgrossamt
				  ,(CASE WHEN ds.createdDate<=@lastMonTHEND AND   ds.SRNDATE < @fDate THEN NULL ELSE (-1 * (isnull(prdSalQty,0)+isnull(PrdUnSalQty,0))) END) prdQty	
				  ,ds.CreatedDate
				  /*Added by durgesh on 03May2018 RDR 2018 001*/
				  ,ISNULL(ds.NRValue,0) as NR
				  ,ISNULL(ds.LPValue,0) as LP
				  ,ISNULL(ds.PrdSelRateAfterTax,0) as PTR
				  /*End*/	
				  FROM JandJConsoleLive.dbo.salesRETURN  ds WITH(nolock)   
				  inner join cdgmASter.businessCalENDer cal ON DATEDIFF(d, ds.srndate, cal.salInvDate) = 0              
				  WHERE distCode = @distCode  
  				  AND CONVERT(VARCHAR(20), CAST(ds.CreatedDate AS DATETIME), 111) >= CONVERT(VARCHAR(20), CAST(@fDate AS DATETIME), 111)
				  AND CONVERT(VARCHAR(20), CAST(ds.CreatedDate AS DATETIME), 111) <= CONVERT(VARCHAR(20), CAST(@tDate AS DATETIME), 111)

				
			END
			ELSE IF @Src = 1 -- Daily Sales
			BEGIN
				  INSERT INTO #TempDS (mon, yr, wkstr,DistCode,PrdCode,SRC,dsMRP,salInvDate,prdgrossamt,prdQty,createdDate
										,NR --added column by durgesh on 03May2018 RDR 2018 001
										,LP --added column by durgesh on 16May2018 RDR 2018 001
										,PTR --added column by durgesh on 16May2018 RDR 2018 001
										  )
				  SELECT cal.monthKey mon, cal.[Year] yr, cal.[Week] wkstr ,DistCode,PrdCode,'DS' SRC
				  ,ds.MRP,ds.salInvDate salInvDate
				  --,prdgrossamt,prdQty
				  ,(CASE WHEN ds.createdDate<=@lastMonTHEND AND   ds.salInvDate < @fDate THEN NULL ELSE prdgrossamt END) prdgrossamt
				  ,(CASE WHEN ds.createdDate<=@lastMonTHEND AND   ds.salInvDate < @fDate THEN NULL ELSE prdQty END) prdQty	
				  ,ds.CreatedDate
				  /*Added by durgesh on 03May2018 RDR 2018 001*/
				  ,ISNULL(ds.NRValue,0) as NR
				  ,ISNULL(ds.LPValue,0) as LP
				  ,ISNULL(ds.PrdSelRateAfterTax,0) as PTR
				  /*End*/
				  FROM JandJConsoleLive.dbo.dailysales  ds WITH(nolock)   
				  inner join cdgmASter.businessCalENDer cal ON DATEDIFF(d, ds.salinvdate, cal.salInvDate) = 0              
				  WHERE distCode = @distCode  
                  AND CONVERT(VARCHAR(20), CAST(ds.CreatedDate AS DATETIME), 111) >= CONVERT(VARCHAR(20), CAST(@fDate AS DATETIME), 111)
				  AND CONVERT(VARCHAR(20), CAST(ds.CreatedDate AS DATETIME), 111) <= CONVERT(VARCHAR(20), CAST(@tDate AS DATETIME), 111)

			END
			ELSE IF @Src = 2  -- Sales Return
			BEGIN
				  INSERT INTO #TempDS (mon, yr, wkstr,DistCode,PrdCode,SRC,dsMRP,salInvDate,prdgrossamt,prdQty,createdDate
										,NR --added column by durgesh on 03May2018 RDR 2018 001
										,LP --added column by durgesh on 16May2018 RDR 2018 001
										,PTR --added column by durgesh on 16May2018 RDR 2018 001
										  )
				  SELECT cal.monthKey mon, cal.[Year] yr, cal.[Week] wkstr ,DistCode,PrdCode,'SR' SRC
				  ,ds.MRP,ds.srndate salInvDate
				  --,(-1 * prdgrossamt) prdgrossamt,(-1 * prdSalQty) prdQty
				  ,(CASE WHEN ds.createdDate<=@lastMonTHEND AND   ds.SRNDATE < @fDate THEN NULL ELSE (-1 * prdgrossamt) END) prdgrossamt
				  ,(CASE WHEN ds.createdDate<=@lastMonTHEND AND   ds.SRNDATE < @fDate THEN NULL ELSE (-1 * (isnull(prdSalQty,0)+isnull(PrdUnSalQty,0))) END) prdQty	
				  ,ds.CreatedDate
				  /*Added by durgesh on 03May2018 RDR 2018 001*/
				  ,ISNULL(ds.NRValue,0) as NR
				  ,ISNULL(ds.LPValue,0) as LP
				  ,ISNULL(ds.PrdSelRateAfterTax,0) as PTR
				  /*End*/
				  FROM JandJConsoleLive.dbo.salesRETURN  ds WITH(nolock)   
				  inner join cdgmASter.businessCalENDer cal ON DATEDIFF(d, ds.srndate, cal.salInvDate) = 0              
				  WHERE distCode = @distCode  
				  AND CONVERT(VARCHAR(20), CAST(ds.CreatedDate AS DATETIME), 111) >= CONVERT(VARCHAR(20), CAST(@fDate AS DATETIME), 111)
				  AND CONVERT(VARCHAR(20), CAST(ds.CreatedDate AS DATETIME), 111) <= CONVERT(VARCHAR(20), CAST(@tDate AS DATETIME), 111)

			END

			DELETE FROM #TEMPDS WHERE prdgrossamt IS NULL
			DELETE FROM #TEMPDS WHERE prdqty IS NULL
			
			/* BuildINg CONtrols */
			INSERT INTO [cdgmaster].[tblPF_secSalesM_CtrlDet]([HdrserNo],[distCode],[prdCode],[PrdQty],[PrdGrossAmt]
															 ,[SRC],[CreatedDate]
															 ,[SalINvDate],[stateCode],[MRP])
			SELECT @lAStCtrlId,DistCode,PrdCode,prdQty,prdgrossamt,SRC,CreatedDate,salINvDate,@stateCode,dsMRP
			FROM #TempDS
		 	
			DECLARE @recFoundDS CHAR(1)
			SELECT @recFoundDS ='N'
			SELECT top 1 @recFoundDS ='Y' FROM #TempDS

			--INSERT INTO cdgmASter.tblVMRjobLog (jobCode, logMsg) values ('RE_FETCH', '1-debug-' + @recFoundDS)

			IF @recFoundDS ='Y'
			BEGIN --{
				UPDATE #TempDS SET  isErrYN = 'Y',
				/*--Commented by durgesh on 03May 2018
				errNR=cdgmaster.f_PF_GetNRapprox(ISNULL(dsMRP,0), salINvdate, prdCode, @stateCode, 'N')
				,errLP=cdgmaster.f_pf_getNRapprox(ISNULL(dsMRP,0), salINvdate, prdCode, @stateCode,'L')
                ,errPTR=cdgmaster.f_pf_getNRapprox(ISNULL(dsMRP,0), salINvdate, prdCode, @stateCode,'P')
				*/
				/*Added by durgesh on 03May2018*/
				errNR=cast(ISNULL(NR,0) as varchar) +'~' + cast(ISNULL(dsMRP,0) as varchar)+'~' +cast(ISNULL(salINvdate,'') as varchar)
				,errLP=cast(ISNULL(LP,0) as varchar) +'~' + cast(ISNULL(dsMRP,0) as varchar)+'~' +cast(ISNULL(salINvdate,'') as varchar)
				,errPTR=cast(ISNULL(PTR,0) as varchar) +'~' + cast(ISNULL(dsMRP,0) as varchar)+'~' +cast(ISNULL(salINvdate,'') as varchar)
				/*End*/

				WHERE ISNULL(dsMRP,0)=0 		
				
				/*Commented by durgesh on 03May 2018
				UPDATE #TempDS SET CHARidx = CHARINDEX('~',errNR) ,
								   CHARidxLP = CHARINDEX('~',errLP) ,
								   CHARidxPTR = CHARINDEX('~',errPTR)	
				WHERE isErrYN = 'Y'
				
				UPDATE #TempDS SET NR  = CONVERT(NUMERIC(16,3),substrINg(errNR,1,CHARidx - 1)), 
								   LP  = CONVERT(NUMERIC(16,3),SUBSTRING(errLP,1,CHARidxLP - 1)) 
								  ,PTR = CONVERT(NUMERIC(16,3),SUBSTRING(errPTR,1,CHARidxPTR - 1)) 					
				WHERE isErrYN = 'Y'
				
				UPDATE #TempDS SET PTR =cdgmASter.f_PF_GetNR(ISNULL(dsMRP,0), salinvdate, prdCode, @stateCode, 'P')
					, LP = cdgmASter.f_PF_GetNR(ISNULL(dsMRP,0), salinvdate, prdCode, @stateCode, 'L')  
					, NR = cdgmASter.f_PF_GetNR(ISNULL(dsMRP,0), salinvdate, prdCode, @stateCode, 'N')  
					
					WHERE ISNULL(dsMRP,0)<>0
					*/
				INSERT INTO cdgmASter.tblPF_NRErrLog (DistCode,PrdCode,NR,DSalesMRP,DSalesDate,plMRP_Dt,errStr)      
				SELECT distCode, prdCode, NR, dsMRP, salInvDate,errNR,'ReFetch' FROM #TempDS WHERE isErrYN = 'Y'

				INSERT INTO cdgmASter.tblPF_NRErrLog (DistCode,PrdCode,NR,DSalesMRP,DSalesDate,errStr)      
				SELECT distCode, prdCode, NR, dsMRP, salInvDate,'ReFetch,NR Error for date:' + CAST(@runMY AS VARCHAR(11)) 
				FROM #TempDS WHERE ISNULL(dsMRP,0)<>0 and ISNULL(NR,0)=0

				 INSERT INTO #TempDailySales (mon, yr, wkstr, DistCode, PrdCode, NR, prdQty, PrdGrossAmt,Src,Ptr, LP, recCnt  
			   , stateCode, dsMRP) 
					   SELECT mon, yr, wkstr, DistCode, prdCode, NR, sum(prdQty) PrdQty, sum(prdGrossAmt) prdGrossAmt,SRC,Ptr, LP, sum(ISNULL(aCnt,0))   
			   , @stateCode, MRP
					   FROM ( SELECT ds.mon, ds.yr, ds.wkstr  
						   , sum(prdQty) PrdQty, sum(prdGrossAmt) prdGrossAmt,DistCode, prdCode, ISNULL(dsMRP, 0) MRP    
						   , NR  , PTR  , LP  
				  , count(*) aCnt,SRC         
					  FROM #TempDS  ds 			  
					 WHERE distCode = @distCode  --and ISNULL(dsMRP,0)<>0          
					group BY distCode, prdCode, ISNULL(dsMRP,0), ds.mon, ds.yr, ds.wkstr, NR , Ptr, LP,SRC
					 )AS tmp    
				   group BY distCode, prdCode, NR, Ptr, LP, mon, yr, wkstr, MRP,SRC
			
				--INSERT INTO cdgmASter.tblVMRjobLog (jobCode, logMsg) values ('RE_FETCH', '2-debug-' )

			IF exists (SELECT * FROM #TempDailySales)  
			BEGIN  --{
					UPDATE #TempDailySales SET wkStr= '' WHERE wkStr is null  
					UPDATE #TempDailySales SET wkStr= replace (replace (wkStr, 'Week', ''), ' ', '')   
					UPDATE #TempDailySales SET wk = CONVERT(INT, wkStr)  
		  
				   SELECT mon,yr,distCode,prdCode,sum(ISNULL(PrdQty,0)) PrdQty, sum(ISNULL(PrdGrossAmt, 0)) PrdGrossAmt, Ptr, Src, NR, LP, 'N' isUPDATEM, @runMM AS runMM, @runYr AS runYr  
					INTO #TempDailySalesMM  
							  FROM #TempDailySales  
				   group BY mon,yr,distCode,prdCode, Ptr, Src, NR, LP    
		             
					BEGIN TRY  
		  
					BEGIN TRANSACTION  
						  
					
					INSERT INTO cdgmASter.tblPF_secSalesM (runMM, runYr, mon,yr,distCode,prdCode,NR,PriceListLP,PriceListPTR,PrdQty,PrdGrossAmt,PtrValue,Src, PrdNrValue, LPvalue)    
					SELECT @runMM, @runYr, mon,yr,distCode,prdCode,isnull(NR,0),ISNULL(LP,0),ISNULL(ptr,0),ISNULL(PrdQty,0),ISNULL(PrdGrossAmt, 0),Ptr * ISNULL(PrdQty, 0),Src, ISNULL(NR,0) * ISNULL(PrdQty, 0), LP * ISNULL(PrdQty, 0)  
					  FROM #TempDailySalesMM  
					WHERE isUPDATEM= 'N' and (@runYr > yr or (@runYr = yr and @runMM > mon))  
		  
					INSERT INTO cdgmASter.tblPF_secSalesM (runMM, runYr, mon,yr,distCode,prdCode,NR,PriceListLP,PriceListPTR,PrdQty,PrdGrossAmt,PtrValue,Src, PrdNrValue, LPvalue)    
					SELECT @runMM, @runYr, mon,yr,distCode,prdCode,isnull(NR,0),ISNULL(LP,0),ISNULL(ptr,0),ISNULL(PrdQty,0),ISNULL(PrdGrossAmt, 0),Ptr * ISNULL(PrdQty, 0),Src, ISNULL(NR,0) * ISNULL(PrdQty, 0), LP * ISNULL(PrdQty, 0)  
					  FROM #TempDailySalesMM  
					WHERE isUPDATEM= 'N' and not (@runYr > yr or (@runYr = yr and @runMM > mon))  

					--INSERT INTO cdgmASter.tblPF_secSalesDistHist (prevStDate, distCode) values (@prevStDate, @distCode)  
		  
					DROP TABLE #TempDailySalesMM  

						--INSERT INTO cdgmASter.tblVMRjobLog (jobCode, logMsg) values ('RE_FETCH', '4-debug-' + @distCode)
					COMMIT   
		  
					END TRY  
					BEGIN CATCH  
		                 
						EXEC cdgmASter.usp_LogErrorInfo 'RE_FETCH', 'usp_PF_secondary_incr_Dist'    
				  
						IF @@Trancount > 0  
							Rollback Tran  
					  END CATCH  
				END  --}
			END --}
				SELECT @recCnt = @recCnt + ISNULL(sum(ISNULL(recCnt,0)),0) FROM #TempDailySales  
				TRUNCATE TABLE #TempDailySales  
		  
				DELETE FROM #tempDist WHERE distCode = @distCode    
		        
				SET @recFound = 'N'  
				SELECT top 1 @recFound = 'Y', @distCode= distCode, @stateCode= stateCode FROM #tempDist ORDER BY stateCode  
		END -- }  distrib loop  
			
			
			--INSERT INTO cdgmASter.tblVMRjobLog (jobCode, logMsg) values ('RE_FETCH', '5-debug-' )

			UPDATE cdgmASter.tblVMRjobLog SET logMsg = ISNULL(logMsg,'') + ':' + CAST(@recCnt AS VARCHAR) WHERE serNo=@lAStMsgId     
		  
			DECLARE @dsPrdQty numeric(16,3), @dsPrdGrossAmt numeric(16,3), @srPrdQty numeric(16,3), @srPrdGrossAmt numeric(16,3) 	  
			
			SELECT @dsPrdGrossAmt=SUM(prdGrossAmt),@dsPrdQty=SUM(PrdQty) FROM cdgmaster.tblpf_SECSalesM where runMM=@runMM and runYr=@runYr AND SRC='DS'		
			SELECT @srPrdGrossAmt=SUM(prdGrossAmt),@srPrdQty=SUM(PrdQty) FROM cdgmaster.tblpf_SECSalesM where runMM=@runMM and runYr=@runYr AND SRC='SR'		

			UPDATE cdgmaster.tblPF_secSalesM_CtrlHDr set DSPrdQty=@dsPrdQty, DSPrdGrossAmt=@dsPrdGrossAmt 
														 , SRPrdQty=@srPrdQty, SRPrdGrossAmt=@srPrdGrossAmt											 
			where serno=@lAStCtrlId

			--INSERT INTO cdgmASter.tblVMRjobLog (jobCode, logMsg) values ('RE_FETCH', '7-debug- TEMP END, no Weekly history' )

		  
		--SELECT @maxToDate = max(prevStDate) FROM cdgmASter.tblPF_secSalesDistHist   
		--DELETE FROM cdgmASter.tblPF_secSalesDistHist WHERE prevStDate < @maxToDate  
		UPDATE cdgmaster.RerunLogs SET isProcessed='Y',runDate=getDate() where serno=@serno

		SET @recProcess='N'

		SELECT top 1 @recProcess='Y',@serno=serno,@runMM=pmon,@runYr=pYr,@PdistCode=pDistCode
					 ,@lastMonthEnd=pLastMonthEnd,@tDate=pFetchTillDate,@src=RefetchFrom
		 FROM cdgmaster.RerunLogs where JobCode='PF_SR' AND isProcessed='N' order by serno 

		INSERT INTO cdgmASter.tblVMRjobLog (jobCode, logMsg) values ('RE_FETCH', 'END run:'+ cast(@tDate AS VARCHAR) )    

		
	END  --}
	
IF(@WaveCnt <> 0)
BEGIN	
	EXEC [cdgmaster].[USP_Invoke_WaveDataCheckUI] @PdistCode,'PF_SR'  
END

DROP TABLE #TempDailySales  
DROP TABLE #tempDist  
DROP TABLE #TempDS
  
SET xact_abort off  
END --}


