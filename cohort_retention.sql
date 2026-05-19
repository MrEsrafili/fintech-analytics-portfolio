-- =============================================================================
-- 01_cohort_retention.sql
-- Purpose : Weekly cohort retention analysis
-- Platform: Digital gold trading app
-- Logic   : A user belongs to the cohort of the week they placed their FIRST
--           order. We then measure how many of those users return to trade in
--           each subsequent week (week_offset 0, 1, 2, …).
-- Business question:
--   "Of the users who first traded in week X, what percentage are still
--    active 1, 2, 4 weeks later — and how much revenue do they generate?"
-- =============================================================================

-- Step 1 – find every user's first order date
WITH first_orders AS (
    SELECT
        user                            AS user_id,
        MIN(createdat)                  AS first_order_date
    FROM   orders
    WHERE  createdat IS NOT NULL
    GROUP  BY user
),

-- Step 2 – assign each user to a cohort week (ISO year-week)
cohorts AS (
    SELECT
        user_id,
        first_order_date,
        strftime('%Y-%W', first_order_date) AS cohort_week
    FROM   first_orders
    WHERE  first_order_date >= '2025-01-01'   -- analysis window; adjust as needed
),

-- Step 3 – cohort size (denominator for retention rate)
cohort_sizes AS (
    SELECT
        cohort_week,
        COUNT(DISTINCT user_id) AS cohort_size
    FROM   cohorts
    GROUP  BY cohort_week
)

-- Step 4 – join subsequent orders back to each user's cohort
SELECT
    c.cohort_week,
    cs.cohort_size,

    -- How many weeks after first order did this activity happen?
    CAST(
        (julianday(o.createdat) - julianday(c.first_order_date)) / 7
        AS INTEGER
    )                                           AS week_offset,

    COUNT(DISTINCT o.user)                      AS retained_users,
    ROUND(
        1.0 * COUNT(DISTINCT o.user) / cs.cohort_size,
        4
    )                                           AS retention_rate,

    -- Revenue metrics per cohort-week slice
    COUNT(o.id)                                 AS total_orders,
    ROUND(SUM(o.requestvolume), 2)              AS total_weight_grams,
    ROUND(SUM(o.totalvalue), 2)                 AS total_revenue,
    ROUND(SUM(o.totalvalue * o.fee), 2)         AS net_fee_revenue,
    ROUND(AVG(o.requestprice), 2)               AS avg_gold_price

FROM       cohorts     c
JOIN       cohort_sizes cs  ON cs.cohort_week = c.cohort_week
LEFT JOIN  orders       o   ON  o.user      = c.user_id
                            AND o.createdat >= c.first_order_date
                            AND o.createdat IS NOT NULL

GROUP BY
    c.cohort_week,
    week_offset

ORDER BY
    c.cohort_week,
    week_offset;
