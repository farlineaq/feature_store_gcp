import logging

from google.cloud import bigquery

from feature_store.acl.dto.input_parameters import InputParameters
from feature_store.acl.dto.big_query_output_validation import BigQueryValidation, SchemaValidation


class SchemaException(Exception):
    def __init__(self, message: str):
        self.message = message
        super().__init__(self.message)


class BigQueryManagement:

    @staticmethod
    def define_client(project: str) -> str:
        return bigquery.Client(project=project)

    @staticmethod
    def run_query(client: bigquery.Client, query: str) -> bigquery.table.RowIterator:
        return client.query(query).result()

    @staticmethod
    def process_count_queries(client: bigquery.Client, query: str) -> int:
        query_job = BigQueryManagement.run_query(client, query)
        return [row[0] for row in query_job][0]

    @staticmethod
    def define_unique_count_query(bq_path: str, entity_columns: list[str]) -> str:
        columns = entity_columns.copy()
        columns.append('feature_timestamp')
        columns = str(tuple(columns)).replace("'", "")
        uniqueness = f"""WITH uniqueness as (
                        SELECT 
                        DISTINCT {columns}
                        FROM {bq_path})"""
        count = f"""{uniqueness}
                    SELECT count(*) FROM uniqueness"""
        return count

    @staticmethod
    def define_count_query(bq_path: str) -> str:
        return f"""SELECT count(*) FROM {bq_path}"""

    @staticmethod
    def define_difference_query(bq_path: str, entity_columns: list[str]) -> str:
        count_query = BigQueryManagement.define_count_query(bq_path)
        unique_count_query = BigQueryManagement.define_unique_count_query(bq_path, entity_columns)
        return f""" SELECT (({count_query}) - ({unique_count_query})) as difference"""

    @staticmethod
    def define_timestamp_validation_query(bq_path: str) -> str:
        return f"SELECT count(*) FROM {bq_path} WHERE feature_timestamp IS NULL"

    @staticmethod
    def process_count_validations(client: bigquery.Client, bq_path: str, entity_columns: list[str], logger: logging.Logger) -> dict[str, int]:
        uniqueness_query = BigQueryManagement.define_difference_query(bq_path, entity_columns)
        timestamp_query = BigQueryManagement.define_timestamp_validation_query(bq_path)
        count_validations = {
            validation: BigQueryManagement.process_count_queries(client, query) for validation, query in zip(['uniqueness_validation', 'timestamp_validation'], [uniqueness_query, timestamp_query])
        }
        for validation in count_validations.keys():
            if (validation == 'timestamp_validation') & (count_validations[validation] > 0):
                logger.warning( f"feature_timestamp column has {count_validations['timestamp_validation']} records in Null. Records in Null Can't be queried on the Feature Group or View")
            elif (validation == 'uniqueness_validation') & (count_validations[validation] > 0):
                logger.warning(f"There are {count_validations['uniqueness_validation']} records that aren't unique with feature_timestamp column and entity columns {entity_columns}")
        return count_validations

    @staticmethod
    def schema_to_dict(schema: list[bigquery.SchemaField]) -> dict[str, str]:
        return {
            schema_field.name: schema_field.field_type for schema_field in schema
        }

    @staticmethod
    def extract_schema_bigquery(client: bigquery.Client, bq_path: str) -> dict[str, str]:
        schema = client.get_table(bq_path).schema
        return BigQueryManagement.schema_to_dict(schema)

    @staticmethod
    def schema_validations(client: bigquery.Client, bq_path: str, entity_columns: list[str]) -> SchemaValidation :
        schema = BigQueryManagement.extract_schema_bigquery(client, bq_path)
        columns_to_check = entity_columns.copy()
        columns_to_check.append('feature_timestamp')
        columns_missing_schema = list(set(columns_to_check) - set(schema.keys()))
        if len(columns_missing_schema) > 0:
            raise SchemaException(f"Columns {columns_missing_schema} are missing on the Table/View {bq_path} ")
        schema_validation = {
            'feature_timestamp_validation': True if schema['feature_timestamp'] == 'TIMESTAMP' else False,
            'entity_type_validation': [
                entity_column for entity_column in entity_columns if schema[entity_column] != 'STRING'
            ]
        }
        schema_validation = SchemaValidation.model_validate(schema_validation)
        if len(schema_validation['entity_type_validation']) > 0:
            raise SchemaException(f"Entity columns {schema_validation['entity_type_validation']} needs to be STRING type on BigQuery")
        if not schema_validation['feature_timestamp_validation']:
            raise SchemaException('Column feature_timestamp needs to be of type TIMESTAMP')
        return schema_validation

    @staticmethod
    def define_bigquery_validations(params: InputParameters, logger: logging.Logger) -> BigQueryValidation:
        project = params.project_id
        bq_path = params.bq_path
        entity_columns = params.entity_columns
        client = bigquery.Client(project)
        schema_validations = BigQueryManagement.schema_validations(client, bq_path, entity_columns)
        count_validations = BigQueryManagement.process_count_validations(client, bq_path, entity_columns, logger)
        count_validations.update(schema_validations)
        return count_validations

    @staticmethod
    def run_bigquery_validations(params: InputParameters, logger: logging.Logger) -> None:
        BigQueryManagement.define_bigquery_validations(params, logger)