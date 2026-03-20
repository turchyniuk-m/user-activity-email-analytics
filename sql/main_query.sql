WITH account_metric AS (
 SELECT
   s.date,
   sp.country AS country,
   ac.send_interval,
   ac.is_verified,
   ac.is_unsubscribed,
   COUNT(DISTINCT ac.id) AS account_cnt
 FROM `DA.account` ac
 JOIN `DA.account_session` acs
   ON ac.id = acs.account_id
 JOIN `DA.session` s
   ON acs.ga_session_id = s.ga_session_id
 JOIN `DA.session_params` sp
   ON s.ga_session_id = sp.ga_session_id
 GROUP BY s.date, sp.country, ac.send_interval, ac.is_verified, ac.is_unsubscribed
),


email_metrics AS (
 SELECT
   DATE_ADD(s.date, INTERVAL es.sent_date DAY) AS sent_date,
   sp.country AS country,
   COUNT(DISTINCT es.id_message) AS sent_msg,
   COUNT(DISTINCT eo.id_message) AS open_msg,
   COUNT(DISTINCT ev.id_message) AS visit_msg,
   ac.send_interval,
   ac.is_verified,
   ac.is_unsubscribed
 FROM `DA.email_sent` es
 LEFT JOIN `DA.email_open` eo
   ON es.id_message = eo.id_message
 LEFT JOIN `DA.email_visit` ev
   ON es.id_message = ev.id_message
 JOIN `DA.account_session` acs
   ON es.id_account = acs.account_id
 JOIN `DA.session` s
   ON acs.ga_session_id = s.ga_session_id
 JOIN `DA.session_params` sp
   ON s.ga_session_id = sp.ga_session_id
 JOIN `DA.account` ac
   ON es.id_account = ac.id
 GROUP BY sent_date, sp.country, ac.send_interval, ac.is_verified, ac.is_unsubscribed
),


union_metrics AS (
 SELECT
   date,
   country,
   send_interval,
   is_verified,
   is_unsubscribed,
   account_cnt,
   0 AS sent_msg,
   0 AS open_msg,
   0 AS visit_msg
 FROM account_metric


 UNION ALL


 SELECT
   sent_date AS date,
   country,
   send_interval,
   is_verified,
   is_unsubscribed,
   0 AS account_cnt,
   sent_msg,
   open_msg,
   visit_msg
 FROM email_metrics
),


union_metrics_1 AS (
 SELECT
   date,
   country,
   send_interval,
   is_verified,
   is_unsubscribed,
   SUM(account_cnt) AS account_cnt,
   SUM(sent_msg) AS sent_msg,
   SUM(open_msg) AS open_msg,
   SUM(visit_msg) AS visit_msg
 FROM union_metrics
 GROUP BY date, country, send_interval, is_verified, is_unsubscribed
),


total_by_countries AS (
 SELECT
   *,
   SUM(account_cnt) OVER(PARTITION BY country) AS total_country_account_cnt,
   SUM(sent_msg) OVER(PARTITION BY country) AS total_country_sent_cnt
 FROM union_metrics_1
),


final AS (
 SELECT
   *,
   DENSE_RANK() OVER(ORDER BY total_country_account_cnt DESC) AS rank_total_country_account_cnt,
   DENSE_RANK() OVER(ORDER BY total_country_sent_cnt DESC) AS rank_total_country_sent_cnt
 FROM total_by_countries
)


SELECT *
FROM final
WHERE rank_total_country_account_cnt <= 10
  OR rank_total_country_sent_cnt <= 10
ORDER BY date, country;
