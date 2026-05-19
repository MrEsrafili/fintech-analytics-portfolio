-- =============================================================================
-- 03_revenue_analysis.sql
-- Purpose : Revenue breakdown by month, channel, and user value segment
-- Platform: Digital gold trading app
-- Logic   : Revenue = SUM(totalvalue); fee revenue = SUM(totalvalue × fee).
--           Three standalone queries — run them individually or via
--           scripts/03_run_analysis.py which executes the first SELECT.
-- Business question:
--   "Which channels and time periods drive the most revenue?
--    How concentrated is revenue — do 20% of users generate 80% of it?"
-- =============================================================================


-- ── Query A: Monthly revenue trend ───────────────────────────────────────────
-- Shows growth or seasonality in trading volume and fees over time.
SELECT
    strftime('%Y-%m', createdat)        AS month,
    COUNT(DISTINCT user)                AS active_traders,
    COUNT(id)                           AS total_orders,
    ROUND(SUM(requestvolume), 2)        AS total_weight_grams,
    ROUND(SUM(totalvalue), 2)           AS gross_revenue,
    ROUND(SUM(totalvalue * fee), 2)     AS net_fee_revenue,
    ROUND(AVG(totalvalue), 2)           AS avg_order_value,
    ROUND(AVG(requestprice), 2)         AS avg_gold_price_per_gram

FROM   orders
WHERE  createdat IS NOT NULL
GROUP  BY month
ORDER  BY month;


-- =============================================================================
-- ── Query B: Revenue by acquisition channel ───────────────────────────────────
-- Identifies which channels produce the highest-value traders.
-- A channel with many users but low revenue per user may need targeting work.
-- =============================================================================
/*
SELECT
    COALESCE(comefrom, 'Unknown')       AS channel,
    COUNT(DISTINCT user)                AS unique_traders,
    COUNT(id)                           AS total_orders,
    ROUND(SUM(totalvalue), 2)           AS gross_revenue,
    ROUND(SUM(totalvalue * fee), 2)     AS net_fee_revenue,
    ROUND(AVG(totalvalue), 2)           AS avg_order_value,
    ROUND(
        1.0 * SUM(totalvalue) / COUNT(DISTINCT user),
        2
    )                                   AS revenue_per_user

FROM   orders
WHERE  createdat IS NOT NULL
GROUP  BY channel
ORDER  BY gross_revenue DESC;
*/


-- =============================================================================
-- ── Query C: User value tiers — Pareto (80/20) analysis ──────────────────────
-- Groups users into top / mid / bottom tercile by lifetime revenue.
-- Typical finding: top 20% of users drive ~80% of revenue.
-- =============================================================================
/*
WITH user_revenue AS (
    SELECT
        user                                            AS user_id,
        COUNT(id)                                       AS order_count,
        ROUND(SUM(totalvalue), 2)                       AS lifetime_revenue,
        ROUND(SUM(totalvalue * fee), 2)                 AS lifetime_fees,
        ROUND(AVG(totalvalue), 2)                       AS avg_order_value,
        NTILE(5) OVER (ORDER BY SUM(totalvalue) DESC)   AS revenue_quintile
    FROM   orders
    WHERE  createdat IS NOT NULL
    GROUP  BY user
)

SELECT
    CASE revenue_quintile
        WHEN 1 THEN 'Top 20%'
        WHEN 2 THEN 'Upper-Mid 20–40%'
        WHEN 3 THEN 'Mid 40–60%'
        WHEN 4 THEN 'Lower-Mid 60–80%'
        WHEN 5 THEN 'Bottom 20%'
    END                                     AS user_tier,
    COUNT(DISTINCT user_id)                 AS num_users,
    SUM(order_count)                        AS total_orders,
    ROUND(SUM(lifetime_revenue), 2)         AS total_revenue,
    ROUND(
        100.0 * SUM(lifetime_revenue) /
        SUM(SUM(lifetime_revenue)) OVER (),
        2
    )                                       AS revenue_share_pct,
    ROUND(AVG(avg_order_value), 2)          AS avg_order_value

FROM   user_revenue
GROUP  BY revenue_quintile
ORDER  BY revenue_quintile;
*/
