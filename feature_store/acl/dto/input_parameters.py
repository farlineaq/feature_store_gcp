import re

from pydantic import BaseModel, field_validator

class InputParameters(BaseModel):
    project_id: str
    zone: str
    bq_path: str
    feature_group_id: str
    entity_columns: list[str]

    @field_validator('bq_path')
    def bq_path_must_contain_three_dots(cls, v):
        pattern = r'\b[\w-]+\.[\w-]+\.[\w-]+\b'
        find_pattern = re.findall(pattern, v)
        if (len(v.split('.')) == 3) and (len(find_pattern) == 1):
            return v
        raise ValueError('bq_path must contain <Project_id>.<Dataset>.<Table/View> form')