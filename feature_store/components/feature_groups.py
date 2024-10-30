import logging

from google.cloud import aiplatform_v1
from google.cloud import bigquery
from google.api_core.operation import Operation
from google.cloud.aiplatform_v1.types import FeatureGroup
from google.cloud.aiplatform_v1 import FeatureRegistryServiceClient

from big_query_validations import BigQueryManagement
from acl.dto.input_parameters import InputParameters

class FeatureGroupError(Exception):
    def __init__(self, message: str):
        self.message = message
        super().__init__(self.message)


class FeatureManagement:

    @staticmethod
    def define_client(zone: str) -> FeatureRegistryServiceClient:
        return aiplatform_v1.FeatureRegistryServiceClient(
            client_options={"api_endpoint": f"{zone}-aiplatform.googleapis.com"}
        )

    @staticmethod
    def define_parent(project_id: str, zone: str) -> str:
        return f"projects/{project_id}/locations/{zone}"

    @staticmethod
    def list_feature_groups(client: FeatureRegistryServiceClient, project_id: str, zone: str) -> dict[str, list[str]]:
        request = aiplatform_v1.ListFeatureGroupsRequest(parent=FeatureManagement.define_parent(project_id, zone))
        feature_groups = client.list_feature_groups(request)
        return {
            feature_group.name.split('/')[-1] : feature_group.big_query.big_query_source.input_uri for feature_group in feature_groups
        }

    @staticmethod
    def define_feature_group(bq_path: str, entity_columns: list[str]) -> aiplatform_v1.FeatureGroup:
        big_query = aiplatform_v1.FeatureGroup.BigQuery(
            big_query_source=aiplatform_v1.BigQuerySource(input_uri=bq_path),
            entity_id_columns=entity_columns
            )
        return aiplatform_v1.FeatureGroup(big_query=big_query)

    @staticmethod
    def define_feature_group_creation_request(
        parent: str, feature_group_id: str, feature_group: FeatureGroup
    ) -> aiplatform_v1.CreateFeatureGroupRequest:
        return aiplatform_v1.CreateFeatureGroupRequest(
            parent=parent,
            feature_group_id=feature_group_id,
            feature_group=feature_group,
        )

    @staticmethod
    def create_feature_group(params: InputParameters, client: FeatureRegistryServiceClient) -> Operation:
        project_id = params.project_id
        zone = params.zone
        bq_path = f'bq://{params.bq_path}'
        feature_group_id = params.feature_group_id
        entity_columns = params.entity_columns

        parent = FeatureManagement.define_parent(project_id, zone)
        feature_group = FeatureManagement.define_feature_group(
            bq_path, entity_columns
        )
        request = FeatureManagement.define_feature_group_creation_request(
            parent, feature_group_id, feature_group
        )
        return client.create_feature_group(request=request)

    @staticmethod
    def run_feature_group_creation(client: FeatureRegistryServiceClient, params: InputParameters, logger: logging.Logger) -> None:
        project_id = params.project_id
        zone = params.zone
        existing_feature_groups  = FeatureManagement.list_feature_groups(client, project_id, zone)
        bq_path = f'bq://{params.bq_path}'
        feature_group_id = params.feature_group_id
        zone = params.zone
        if feature_group_id not in existing_feature_groups.keys():
            FeatureManagement.create_feature_group(params, client)
            logger.info(f'The Feature Group {feature_group_id} was created in zone {zone}')
        else:
            if existing_feature_groups[feature_group_id] != bq_path:
                raise FeatureGroupError(
                    f"The Feature Group {feature_group_id} already exists in zone {zone} and the BigQuery source isn't {bq_path}. Is {existing_feature_groups[feature_group_id]}")
            elif existing_feature_groups[feature_group_id] == bq_path:
                logger.info(f"The Feature Group {feature_group_id} already exists in zone {zone} with source {bq_path} and Feature Creation will run on Features that doesn't exist" )
        if bq_path in existing_feature_groups.values():
            feature_groups_using_table = [fg for fg in existing_feature_groups.keys() if (existing_feature_groups[fg] == bq_path)]
            logger.warning(f'The BigQuery Table/View {bq_path} is in use by Feature Groups {feature_groups_using_table} on zone {zone}') if (feature_groups_using_table[0] != feature_group_id) else None

    @staticmethod
    def define_feature_parent(project_id: str, zone: str, feature_group_id: str) -> str:
        parent = FeatureManagement.define_parent(project_id, zone)
        return f"{parent}/featureGroups/{feature_group_id}"

    @staticmethod
    def define_feature(parent: str, feature_name: str) -> aiplatform_v1.Feature:
        name = f"{parent}/features/{feature_name}"
        return aiplatform_v1.Feature(name=name, version_column_name=feature_name)

    @staticmethod
    def define_feature_request(
        parent: str, feature: aiplatform_v1.Feature, feature_name: str
    ) -> aiplatform_v1.CreateFeatureRequest:
        return aiplatform_v1.CreateFeatureRequest(
            parent=parent, feature=feature, feature_id=feature_name
        )

    @staticmethod
    def create_feature(client: FeatureRegistryServiceClient, feature_parent: str, feature_name: str) -> Operation:
        feature = FeatureManagement.define_feature(feature_parent, feature_name)
        request = FeatureManagement.define_feature_request(
            feature_parent, feature, feature_name
        )
        return client.create_feature(request=request)

    @staticmethod
    def extract_feature_column_names_from_schema(bq_client: bigquery.Client, bq_path: str, entity_columns: list[str]) -> list[str]:
        schema = BigQueryManagement.extract_schema_bigquery(bq_client, bq_path)
        return [
            schema_field
            for schema_field in schema.keys()
            if schema_field not in entity_columns and schema_field != 'feature_timestamp'
        ]

    @staticmethod
    def list_existing_features(registry_client: FeatureRegistryServiceClient, parent: str) -> list[str]:
        request = aiplatform_v1.ListFeaturesRequest(parent=parent)
        return [feature.name.split('/')[-1] for feature in registry_client.list_features(request=request)]

    @staticmethod
    def define_features_to_create(registry_client_client: FeatureRegistryServiceClient,
            parent: str,
            project_id: str,
            bq_path: str,
            entity_columns: list[str]
    ) -> list[str]:
        bq_client = bigquery.Client(project_id)
        existing_features = FeatureManagement.list_existing_features(registry_client_client, parent)
        feature_list = FeatureManagement.extract_feature_column_names_from_schema(bq_client, bq_path, entity_columns)
        return list(set(feature_list) - set(existing_features))

    @staticmethod
    def create_features(client: FeatureRegistryServiceClient, params: InputParameters, logger: logging.Logger) -> None:
        project_id = params.project_id
        zone = params.zone
        bq_path = params.bq_path
        entity_columns = params.entity_columns
        feature_group_id = params.feature_group_id
        feature_parent = FeatureManagement.define_feature_parent(project_id, zone, feature_group_id)
        features_to_create = FeatureManagement.define_features_to_create(client, feature_parent, project_id, bq_path, entity_columns)
        [
            FeatureManagement.create_feature(client, feature_parent, feature_name)
            for feature_name in features_to_create
        ]
        logger.info(f"Features {features_to_create} were created in zone {zone} for Feature Group {feature_group_id}") if len(features_to_create) >0 else None

    @staticmethod
    def create_feature_group_and_features(params: InputParameters, logger: logging.Logger) -> None:
        client = FeatureManagement.define_client(params.zone)
        FeatureManagement.run_feature_group_creation(client, params, logger)
        FeatureManagement.create_features(client, params, logger)