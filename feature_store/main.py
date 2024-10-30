import yaml
import logging

from feature_store.components.feature_groups import FeatureManagement
from feature_store.components.big_query_validations import BigQueryManagement
from acl.dto.input_parameters import InputParameters

logger = logging.getLogger(__name__)
logging.basicConfig(format='%(asctime)s %(levelname)s: %(message)s', datefmt="%d/%m/%Y %I:%M:%S", level=logging.INFO)

if __name__ == '__main__':
    with open('parameters.yaml', 'r') as stream:
        parameters = yaml.safe_load(stream)
    parameters = InputParameters.model_validate(parameters)
    BigQueryManagement.run_bigquery_validations(parameters, logger)
    FeatureManagement.create_feature_group_and_features(parameters, logger)