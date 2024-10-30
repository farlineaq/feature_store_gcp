CREATE TABLE `mlops_feature_store.plu2vec-gerencia_10-predictions` (
    model_id STRING,
    prediction_id STRING,
    item_id STRING,
    plu_id BIGINT,
    relevance_score NUMERIC,
    feature_timestamp TIMESTAMP
)
PARTITION BY TIMESTAMP_TRUNC(feature_timestamp, DAY)
    OPTIONS (
    require_partition_filter = TRUE
);
CREATE TABLE `mlops_feature_store.plu2vec-gerencia_30_40-predictions` (
    model_id STRING,
    prediction_id STRING,
    item_id STRING,
    plu_id BIGINT,
    relevance_score NUMERIC,
    feature_timestamp TIMESTAMP
)
PARTITION BY TIMESTAMP_TRUNC(feature_timestamp, DAY)
    OPTIONS (
    require_partition_filter = TRUE
);
CREATE TABLE `mlops_feature_store.plu2vec-gerencia_50-predictions` (
    model_id STRING,
    prediction_id STRING,
    item_id STRING,
    plu_id BIGINT,
    relevance_score NUMERIC,
    feature_timestamp TIMESTAMP
)
PARTITION BY TIMESTAMP_TRUNC(feature_timestamp, DAY)
    OPTIONS (
    require_partition_filter = TRUE
)