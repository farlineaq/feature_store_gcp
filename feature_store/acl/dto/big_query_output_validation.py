from pydantic import BaseModel

class BigQueryValidation(BaseModel):
    uniqueness_validation: int
    timestamp_validation: int
    entity_type_validation: list[str]
    feature_timestamp_validation: bool

class SchemaValidation(BaseModel):
    feature_timestamp_validation: bool
    entity_type_validation: list[str]