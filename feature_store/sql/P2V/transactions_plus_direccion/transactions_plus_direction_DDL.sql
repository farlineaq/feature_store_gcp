CREATE TABLE `mlops_feature_store.transactions_plus_direction` (
  TransactionID INT64,
  PluId STRING,
  DireccionCD INT64
)
PARTITION BY
  RANGE_BUCKET(DireccionCD, GENERATE_ARRAY(0,100,10))
OPTIONS (
  require_partition_filter = TRUE
);