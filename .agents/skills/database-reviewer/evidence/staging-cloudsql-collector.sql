-- collector_id: staging-cloudsql-context-v1
-- Execute each SELECT separately through the sanctioned Staging read-only
-- Cloud SQL wrapper. Do not add COUNT(*), EXPLAIN ANALYZE, row samples, or
-- payload projections.

-- query_id: database_identity_v1
SELECT current_timestamp AS observed_at,
       current_database() AS database_name,
       current_setting('server_version') AS server_version,
       pg_is_in_recovery() AS is_replica,
       pg_database_size(current_database()) AS database_bytes;

-- query_id: live_observed_settings_v1
SELECT name, setting, unit, source
FROM pg_settings
WHERE name IN (
  'autovacuum',
  'effective_cache_size',
  'idle_in_transaction_session_timeout',
  'lock_timeout',
  'maintenance_work_mem',
  'max_connections',
  'max_wal_size',
  'shared_buffers',
  'statement_timeout',
  'track_counts',
  'work_mem'
)
ORDER BY name;

-- query_id: physical_relation_summary_v1
WITH physical AS (
  SELECT c.oid,
         pg_relation_size(c.oid) AS heap_bytes,
         pg_indexes_size(c.oid) AS index_bytes,
         CASE
           WHEN c.reltoastrelid = 0 THEN 0
           ELSE pg_total_relation_size(c.reltoastrelid)
         END AS toast_bytes,
         pg_total_relation_size(c.oid) AS total_bytes
  FROM pg_class AS c
  JOIN pg_namespace AS n ON n.oid = c.relnamespace
  WHERE c.relkind IN ('r', 'm')
    AND n.nspname NOT IN ('pg_catalog', 'information_schema')
    AND n.nspname !~ '^pg_toast'
)
SELECT current_timestamp AS observed_at,
       count(*) AS physical_relation_count,
       sum(total_bytes) AS user_relation_total_bytes,
       sum(heap_bytes) AS heap_total_bytes,
       sum(index_bytes) AS index_total_bytes,
       sum(toast_bytes) AS toast_total_bytes,
       sum(total_bytes - heap_bytes - index_bytes - toast_bytes) AS auxiliary_total_bytes
FROM physical;

-- query_id: largest_physical_relations_v1
WITH physical AS (
  SELECT c.oid,
         n.nspname AS schema_name,
         c.relname,
         c.relkind,
         COALESCE(s.n_live_tup, c.reltuples)::bigint AS estimated_live_rows,
         COALESCE(s.n_dead_tup, 0)::bigint AS estimated_dead_rows,
         s.last_analyze,
         s.last_autoanalyze,
         pg_relation_size(c.oid) AS heap_bytes,
         pg_indexes_size(c.oid) AS index_bytes,
         CASE
           WHEN c.reltoastrelid = 0 THEN 0
           ELSE pg_total_relation_size(c.reltoastrelid)
         END AS toast_bytes,
         pg_total_relation_size(c.oid) AS total_bytes
  FROM pg_class AS c
  JOIN pg_namespace AS n ON n.oid = c.relnamespace
  LEFT JOIN pg_stat_user_tables AS s ON s.relid = c.oid
  WHERE c.relkind IN ('r', 'm')
    AND n.nspname NOT IN ('pg_catalog', 'information_schema')
    AND n.nspname !~ '^pg_toast'
)
SELECT schema_name,
       relname,
       relkind,
       estimated_live_rows,
       estimated_dead_rows,
       last_analyze,
       last_autoanalyze,
       heap_bytes,
       index_bytes,
       toast_bytes,
       total_bytes - heap_bytes - index_bytes - toast_bytes AS auxiliary_bytes,
       total_bytes
FROM physical
ORDER BY total_bytes DESC
LIMIT 20;
