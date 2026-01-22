-- 1. What is the total amount each customer spent at the restaurant?

SELECT 
	CUSTOMER_ID, 
	SUM(PRICE) AS TOTAL_AMOUNT
FROM SALES S JOIN MENU M ON S.PRODUCT_ID=M.PRODUCT_ID
GROUP BY CUSTOMER_ID;

------------------------------------------------------------------------------------------------------------------------------------------------------

-- 2. How many days has each customer visited the restaurant?

SELECT 
	CUSTOMER_ID, 
	COUNT(DISTINCT ORDER_DATE) AS DAYS_VISITED
FROM SALES 
GROUP BY CUSTOMER_ID;

------------------------------------------------------------------------------------------------------------------------------------------------------

-- 3. What was the first item from the menu purchased by each customer?

WITH FIRST_ORDER AS 
(
	SELECT 
		*, 
		MIN(ORDER_DATE) OVER (PARTITION BY CUSTOMER_ID) AS FIRST_DATE
	FROM SALES S
)
SELECT 
	DISTINCT CUSTOMER_ID,
	PRODUCT_NAME 
FROM FIRST_ORDER F
JOIN MENU M ON F.PRODUCT_ID=M.PRODUCT_ID
WHERE ORDER_DATE=FIRST_DATE;

------------------------------------------------------------------------------------------------------------------------------------------------------

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?

WITH ITEM_PURCHASED AS
(
	SELECT 
		PRODUCT_ID, 
		COUNT(1) AS NO_OF_TIMES_PURCHASED FROM SALES
	GROUP BY PRODUCT_ID
	ORDER BY NO_OF_TIMES_PURCHASED DESC LIMIT 1
)
SELECT P
	RODUCT_NAME 
FROM ITEM_PURCHASED I
JOIN MENU M ON I.PRODUCT_ID=M.PRODUCT_ID;

------------------------------------------------------------------------------------------------------------------------------------------------------

-- 5. Which item was the most popular for each customer?

WITH ITEM_PURCHASED AS 
(
	SELECT 
		CUSTOMER_ID, 
		PRODUCT_ID, 
		COUNT(1) AS ITEM_COUNT FROM SALES
	GROUP BY CUSTOMER_ID, PRODUCT_ID
	ORDER BY ITEM_COUNT
),
MAX_PURCHASED AS
(
	SELECT 
		*, 
		MAX(ITEM_COUNT) OVER (PARTITION BY CUSTOMER_ID) AS MAX_COUNT
	FROM ITEM_PURCHASED
)
SELECT 
	CUSTOMER_ID,
	PRODUCT_NAME
FROM MAX_PURCHASED S
JOIN MENU M ON S.PRODUCT_ID=M.PRODUCT_ID
WHERE ITEM_COUNT=MAX_COUNT;

------------------------------------------------------------------------------------------------------------------------------------------------------

-- 6. Which item was purchased first by the customer after they became a member?

WITH FIRST_ORDER AS
(
	SELECT 
		S.CUSTOMER_ID, 
		PRODUCT_ID, 
		FIRST_VALUE(PRODUCT_ID) OVER(PARTITION BY S.CUSTOMER_ID ORDER BY ORDER_DATE) AS PROD
	FROM SALES S
	JOIN MEMBERS M ON S.CUSTOMER_ID = M.CUSTOMER_ID AND S.ORDER_DATE >= M.JOIN_DATE
)
SELECT 
	DISTINCT CUSTOMER_ID, 
	PRODUCT_NAME
FROM FIRST_ORDER F 
JOIN MENU M ON PROD=M.PRODUCT_ID;

------------------------------------------------------------------------------------------------------------------------------------------------------

-- 7. Which item was purchased just before the customer became a member?

WITH FIRST_ORDER AS
(
	SELECT 
		S.*, 
		FIRST_VALUE(PRODUCT_ID) OVER(PARTITION BY S.CUSTOMER_ID ORDER BY ORDER_DATE DESC) AS PROD
	FROM SALES S
	JOIN MEMBERS M ON S.CUSTOMER_ID = M.CUSTOMER_ID AND S.ORDER_DATE < M.JOIN_DATE
)
SELECT 
	DISTINCT CUSTOMER_ID, 
	PRODUCT_NAME
FROM FIRST_ORDER F 
JOIN MENU M ON PROD=M.PRODUCT_ID;

------------------------------------------------------------------------------------------------------------------------------------------------------

-- 8. What is the total items and amount spent for each member before they became a member?

WITH CTE AS
(
	SELECT 	
		S.*, 
		COUNT(1) OVER(PARTITION BY S.CUSTOMER_ID) AS TOTAL_ITEMS,
		SUM(PRICE) OVER(PARTITION BY S.CUSTOMER_ID) AS AMOUNT_SPENT
	FROM SALES S
	JOIN MEMBERS M ON S.CUSTOMER_ID = M.CUSTOMER_ID AND S.ORDER_DATE < M.JOIN_DATE
	JOIN MENU M1 ON M1.PRODUCT_ID=S.PRODUCT_ID
)
SELECT 
	DISTINCT CUSTOMER_ID, 
	TOTAL_ITEMS, 
	AMOUNT_SPENT
FROM CTE;

------------------------------------------------------------------------------------------------------------------------------------------------------

-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

WITH POINTS_EARNED AS
(
	SELECT 	
		CUSTOMER_ID, 
		PRODUCT_NAME, 
		CASE WHEN PRODUCT_NAME = 'sushi' THEN PRICE*20 ELSE PRICE*10 END AS POINTS
	FROM SALES S 
	JOIN MENU M ON S.PRODUCT_ID=M.PRODUCT_ID
)
SELECT 
	CUSTOMER_ID,
	SUM(POINTS)
FROM POINTS_EARNED 
GROUP BY CUSTOMER_ID;

------------------------------------------------------------------------------------------------------------------------------------------------------

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?

WITH POINTS_EARNED AS
(
	SELECT 
		S.CUSTOMER_ID,
		PRICE*20 AS POINTS
	FROM SALES S 
	JOIN MENU M ON S.PRODUCT_ID=M.PRODUCT_ID
	JOIN MEMBERS M1 ON M1.CUSTOMER_ID=S.CUSTOMER_ID AND M1.JOIN_DATE<=S.ORDER_DATE
	WHERE DATE_ADD(JOIN_DATE, INTERVAL 7 DAY)>ORDER_DATE
	ORDER BY S.CUSTOMER_ID
)
SELECT CUSTOMER_ID,SUM(POINTS) AS POINTS
FROM POINTS_EARNED 
GROUP BY CUSTOMER_ID;


------------------------------------------------------------------------------------------------------------------------------------------------------

--Danny and his team can use to quickly derive insights without needing to join the underlying tables using SQL.

SELECT 
	S.CUSTOMER_ID, 
	ORDER_DATE,
	PRODUCT_NAME,
	PRICE, 
	CASE WHEN JOIN_DATE IS NULL THEN 'N' ELSE 'Y' END AS MEMBER
FROM SALES S
JOIN MENU P ON S.PRODUCT_ID = P.PRODUCT_ID
LEFT JOIN MEMBERS M ON M.CUSTOMER_ID = S.CUSTOMER_ID AND ORDER_DATE>=JOIN_DATE;

------------------------------------------------------------------------------------------------------------------------------------------------------

-- Danny also requires further information about the ranking of customer products, but he purposely does not need the ranking for non-member purchases 
-- so he expects null ranking values for the records when customers are not yet part of the loyalty program.

WITH CTE AS 
(
SELECT 
	S.CUSTOMER_ID, 
	ORDER_DATE,
	PRODUCT_NAME,
	PRICE, 
	CASE WHEN JOIN_DATE IS NULL THEN 'N' ELSE 'Y' END AS MEMBER
FROM SALES S 
JOIN MENU P ON S.PRODUCT_ID = P.PRODUCT_ID
LEFT JOIN MEMBERS M ON M.CUSTOMER_ID = S.CUSTOMER_ID AND ORDER_DATE>=JOIN_DATE
)
SELECT 
	*, 
	CASE WHEN MEMBER = 'N' THEN NULL ELSE 0 END AS RANKING
FROM CTE WHERE MEMBER = 'N'
UNION ALL
SELECT 
	*, 
	CASE WHEN MEMBER = 'Y' THEN RANK() OVER(PARTITION BY CUSTOMER_ID ORDER BY ORDER_DATE) ELSE NULL END AS RANKING
FROM CTE WHERE MEMBER = 'Y' ORDER BY CUSTOMER_ID;
