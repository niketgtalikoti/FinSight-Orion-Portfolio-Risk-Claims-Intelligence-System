USE finsight_db;

CREATE TABLE finsight_orion (
    contract_id INT,
    customer_id INT,
    product_type VARCHAR(50),
    asset_type VARCHAR(50),
    region VARCHAR(50),
    origination_channel VARCHAR(50),
    credit_score INT,
    loan_amount DECIMAL(12,2),
    interest_rate DECIMAL(5,2),
    emi_amount DECIMAL(12,2),
    tenure_months INT,
    start_date DATE,
    end_date DATE,
    payment_status VARCHAR(20),
    days_late INT,
    default_flag TINYINT,
    claim_flag TINYINT,
    claim_amount DECIMAL(12,2)
);
/*-------------------------------------------------------------------------------------------------------------------------------------*/

DESCRIBE finsight_orion;
SELECT * FROM finsight_orion LIMIT 10;

-- *EXPLORATORY DATA ANALYSIS*
-- 2.1 Basic distribution checks

-- Total contracts:

SELECT COUNT(*) AS total_contracts FROM finsight_orion;
/* there are total 10000 Contracts are present*/
-- Summary stats for financial fields:

SELECT 
    MIN(PremiumAmount), MAX(PremiumAmount), AVG(PremiumAmount),
    MIN(creditScore), MAX(creditScore), AVG(creditScore)
FROM finsight_orion;
/*       Premium Amount     creditScore
   Min=      0                378
   Max=     2096827           900
   Avg=    4845.0112         649.2817*/
/*---------------------------------------------------------------------------------------------------------------------*/
-- *2.2 Categorical distributions*
-- Contracts by product:

SELECT productType, COUNT(*) 
FROM finsight_orion
GROUP BY productType;
 /*Contract Distribution by Product Type
Results
Product Type	       Contracts
Vehicle Insurance	     2433
Loan	                 1539
Equipment Insurance	     1039
Operating Lease	         1488
Property Insurance	      501


The portfolio is dominated by Vehicle Insurance (2433 contracts), showing strong customer demand in this category. 
Loans form the next major segment with 1539 contracts, followed by commercial-focused products like Operating Lease (1488) 
and Equipment Insurance (1039).Property Insurance is the smallest segment (501 contracts)—highlighting a clear opportunity
 for expansion and targeted marketing.*/

-- Contracts by region:
SELECT region, COUNT(*)
FROM finsight_orion
GROUP BY region
ORDER BY COUNT(*) DESC;
/* | Region      | Contracts |
| ----------- | --------- |
|  North      |    2253   |
|   South     |   2146    |
|   West      |   2044    |
|   East      |   1805    |
|   Central   |   1772    |

The North region leads with 2253 contracts, making it the strongest market for the company. 
The South (2146) and West (2044) regions follow closely, showing balanced business activity across major zones.
The East (1805) and Central (1772) regions have slightly lower volumes, indicating potential areas for
 deeper market penetration and targeted sales efforts.*/

/*---------------------------------------------------------------------------------------------------------------------*/


-- 2.3 Risk behaviour
-- Defaults by region:

SELECT 
    Region, 
    COUNT(*) AS total_contracts, 
    SUM(IsDefault) AS total_defaults,
    ROUND(SUM(IsDefault) / COUNT(*) * 100, 2) AS default_rate_pct
FROM finsight_orion
GROUP BY Region
ORDER BY default_rate_pct DESC;
/* | Region      | Total Contracts | Total Defaults | Default Rate (%) |
| ----------- | --------------- | -------------- | ---------------- |
| **South**   | 2146            | 543            | **25.30%**       |
| **North**   | 2253            | 539            | **23.93%**       |
| **West**    | 2044            | 487            | **23.81%**       |
| **Central** | 1772            | 424            | **23.92%**       |
| **East**    | 1805            | 411            | **22.77%**       |
The South has the highest default rate (25.3%), making it the riskiest region.
The East shows the lowest defaults (22.8%), indicating better repayment behavior.
Other regions remain stable around 23–24%.*/

-- Defaults by credit score bucket:
SELECT 
    CASE 
        WHEN CreditScore < 600 THEN 'High Risk (<600)'
        WHEN CreditScore BETWEEN 600 AND 700 THEN 'Medium Risk (600-700)'
        ELSE 'Low Risk (>700)' 
    END AS score_band,
    COUNT(*) AS total_customers,
    SUM(IsDefault) AS total_defaults,
    ROUND(SUM(IsDefault) / COUNT(*) * 100, 2) AS default_rate_pct
FROM finsight_orion
GROUP BY score_band
ORDER BY default_rate_pct DESC;
/*| Score Band                | Total Customers | Total Defaults | Default Rate (%) |
| ------------------------- | --------------- | -------------- | ---------------- |
| **High Risk (<600)**      | 2696            | 992            | **36.80%**       |
| **Low Risk (>700)**       | 2657            | 710            | **26.72%**       |
| **Medium Risk (600–700)** | 4647            | 697            | **15.00%**       |
Lower credit scores show much higher default rates — High-risk customers (<600) default more than double compared to medium-risk customers.
/*-----------------------------------------------------------------------------------------------------------------------------*/


-- 2.4 Claim behaviour
SELECT 
    AssetType,
    COUNT(*) AS total_contracts,
    SUM(HasClaim) AS total_claims,
    ROUND(SUM(HasClaim) / COUNT(*) * 100, 2) AS claim_rate_pct,
    SUM(ClaimsCount) AS total_claim_events
FROM finsight_orion
GROUP BY AssetType
ORDER BY claim_rate_pct DESC;
/*| Asset Type    | Total Contracts | Total Claims | Claim Rate (%) | Total Claim Events |
| ------------- | --------------- | ------------ | -------------- | ------------------ |
| **Car**       | 1592            | 58           | **3.66%**      | 62                 |
| **Truck**     | 1624            | 48           | **2.95%**      | 48                 |
| **Equipment** | 1478            | 28           | **1.89%**      | 34                 |
| **Bike**      | 1102            | 20           | **1.80%**      | 31                 |
| **Other**     | 361             | 6            | **1.62%**      | 27                 |
| **Property**  | 1687            | 20           | **1.19%**      | 20                 |
Cars and trucks show the highest claim rates, with cars leading at 3.66%. Property and 
equipment have the lowest claim rates, indicating fewer risk events.*/
/*--------------------------------------------------------------------------------------------------------------------------*/

-- *3 — ADVANCED ANALYSIS & INSIGHTS*

ALTER TABLE finsight_orion      /*Add new column*/
ADD COLUMN LastPaymentDate_converted DATE;

UPDATE finsight_orion         /*Convert DD-MM-YYYY → DATE*/
SET LastPaymentDate_converted = STR_TO_DATE(LastPaymentDate, '%d-%m-%Y')
WHERE ContractID IS NOT NULL;
-- 3.1 Identify high-risk contracts using rules + window functions
-- Top 100 customers with most late payments:

SELECT 
    CustomerID,
    total_defaults,
    rank_pos
FROM (
    SELECT 
        CustomerID,
        SUM(DATEDIFF(LastPaymentDate, StartDate)) AS total_days_late,
        SUM(IsDefault) AS total_defaults,
        ROW_NUMBER() OVER (ORDER BY SUM(DATEDIFF(LastPaymentDate, StartDate)) DESC) AS rank_pos
    FROM finsight_orion
    GROUP BY CustomerID
) t
ORDER BY total_days_late DESC
LIMIT 100;
/*| CustomerID | Total Defaults | Rank |
| ---------- | -------------- | ---- |
| CUST97961  | 2              | 8459 |
| CUST66640  | 1              | 8458 |
| CUST70008  | 1              | 8457 |
| CUST67179  | 1              | 8456 |
| CUST75392  | 1              | 8455 |
| CUST74912  | 1              | 8454 |
| CUST40177  | 1              | 8453 |
| CUST91279  | 1              | 8452 |
| CUST87263  | 1              | 8451 |
| CUST98320  | 1              | 8450 |
Very few customers have repeated late payments — only one customer shows 2 defaults, and the rest have single defaults.
This suggests late payment behavior is not widespread, indicating generally good repayment discipline.*/
/*----------------------------------------------------------------------------------------------------------------------------*/
-- 3.2 Core drivers of defaults 

-- Default rate by asset type:

SELECT 
    AssetType,
    ROUND(SUM(IsDefault) / COUNT(*) * 100, 2) AS default_rate
FROM finsight_orion
GROUP BY AssetType
ORDER BY default_rate DESC;
/*| AssetType     | default_rate (%) |
| ------------- | ---------------- |
| **Equipment** | **25.04**        |
| **Bike**      | **24.76**        |
| **Property**  | **24.42**        |
| **Truck**     | **24.20**        |
| **Other**     | **22.85**        |
| **Car**       | **22.75**        |
Equipment, Bike, Property, and Truck loans show the highest default risk (~24–25%), 
while Car and Other loans have lower default rates (~22–23%). */


-- Default rate by origination channel:

SELECT 
    Channel,
    ROUND(SUM(IsDefault) / COUNT(*) * 100, 2) AS default_rate
FROM finsight_orion
GROUP BY Channel
ORDER BY default_rate DESC;
/*Channel     default_rate
MobileApp       25.94
Broker          24.41
Online          24.33
Branch          24.28
Dealer          22.31
The FinSight_orion channel is a critical outlier with a default rate of 39%, significantly higher than 
the next channel (MobileApp at 25.94%) and the low-risk core (22%–24%).

Action Required: Immediate, deep investigation into the underwriting and customer acquisition for 
FinSight_orion is necessary to reduce portfolio risk.*/
/*--------------------------------------------------------------------------------------------------------------------------*/

-- 3.3 Profitability check

-- Net profit = EMI collected – principal – claims

SELECT 
    ContractID,
    (ContractAmount * InterestRate * (TenureMonths / 12)) 
    - IFNULL(ClaimsCount, 0) AS net_profit
FROM finsight_orion;
/*| ContractID | net_profit         |
| ---------- | ------------------ |
| CT000003   | 0                  |
| CT000004   | 25720.6208         |
| CT000005   | 0                  |
| CT000006   | 617138.7705        |
| CT000007   | 0                  |
Most contracts show zero or negative profit, while a few high-value contracts drive 
almost all the profitability — especially CT000023, CT000008, and CT000006.*/


-- Loss-making contracts:

SELECT *
FROM (
    SELECT 
        ContractID,
        ProductType,
        CASE 
            WHEN ProductType IN ('Loan', 'Lease', 'Operating Lease') THEN
                (ContractAmount * InterestRate * (TenureMonths / 12))
                - IFNULL(ClaimsCount, 0)

            WHEN ProductType LIKE '%Insurance%' THEN
                PremiumAmount - IFNULL(ClaimsCount, 0)

            ELSE 0
        END AS net_profit
    FROM finsight_orion
) t
WHERE net_profit < 0
ORDER BY net_profit;
/*| ContractID | net_profit         |
| ContractID                         | ProductType         | net_profit |
| ---------------------------------- | ------------------- | ---------- |
| CT000618                           | Equipment Insurance | -1         |
| CT001915                           | Vehicle Insurance   | -1         |
| CT000529                           | Vehicle Insurance   | -1         |
| CT001664                           | Vehicle Insurance   | -1         |
| CT001257                           | Vehicle Insurance   | -1         |
| CT000244                           | Vehicle Insurance   | -1         |
| CT002272                           | Vehicle Insurance   | -1         |
| CT000312                           | Vehicle Insurance   | -1         |
| CT001327                           | Vehicle Insurance   | -1         |
| CT001330                           | Vehicle Insurance   | -1         |
| CT002201                           | Vehicle Insurance   | -1         |
| (and more rows… total 30 returned) |                     |            |

Almost all loss-making contracts come from Vehicle Insurance, with only one from Equipment 
Insurance — showing Vehicle Insurance is the primary driver of negative profitability.*/