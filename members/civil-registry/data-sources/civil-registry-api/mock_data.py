import json
import os
from dataclasses import dataclass
from datetime import date
import strawberry

@strawberry.type
class Informant:
    signature: str
    full_name: str
    residence: str
    relationship_to_baby: str
    nic: str

@strawberry.type
class Father:
    name: str
    nic: str
    birth_date: date
    birth_place: str
    race: str

@strawberry.type
class Mother:
    name: str
    nic: str
    birth_date: date
    birth_place: str
    race: str
    age_at_birth: int

@dataclass
class PersonInfo:
    id: int
    br_no: str
    district: str
    division: str
    birth_date: date
    birth_place: str
    name: str
    sex: str
    nic: str
    are_parents_married: bool
    is_grandfather_born_in_sri_lanka: bool
    father: Father
    mother: Mother
    date_of_registration: date
    registrar_signature: str
    informant: Informant

@strawberry.type
class PersonData:
    id: int
    br_no: str
    nic: strawberry.ID
    district: str
    division: str
    birth_date: date
    birth_place: str
    name: str
    sex: str
    are_parents_married: bool
    is_grandfather_born_in_sri_lanka: bool
    father: Father
    mother: Mother
    date_of_registration: date
    registrar_signature: str
    informant: Informant


def _build_person(record: dict) -> PersonData:
    """Construct a PersonData instance from a plain dict (parsed from JSON)."""
    father = Father(
        name=record["father"]["name"],
        nic=record["father"]["nic"],
        birth_date=date.fromisoformat(record["father"]["birth_date"]),
        birth_place=record["father"]["birth_place"],
        race=record["father"]["race"],
    )
    mother = Mother(
        name=record["mother"]["name"],
        nic=record["mother"]["nic"],
        birth_date=date.fromisoformat(record["mother"]["birth_date"]),
        birth_place=record["mother"]["birth_place"],
        race=record["mother"]["race"],
        age_at_birth=record["mother"]["age_at_birth"],
    )
    informant = Informant(
        signature=record["informant"]["signature"],
        full_name=record["informant"]["full_name"],
        residence=record["informant"]["residence"],
        relationship_to_baby=record["informant"]["relationship_to_baby"],
        nic=record["informant"]["nic"],
    )
    return PersonData(
        id=record["id"],
        br_no=record["br_no"],
        district=record["district"],
        division=record["division"],
        birth_date=date.fromisoformat(record["birth_date"]),
        birth_place=record["birth_place"],
        name=record["name"],
        sex=record["sex"],
        nic=strawberry.ID(record["nic"]),
        are_parents_married=record["are_parents_married"],
        is_grandfather_born_in_sri_lanka=record["is_grandfather_born_in_sri_lanka"],
        father=father,
        mother=mother,
        date_of_registration=date.fromisoformat(record["date_of_registration"]),
        registrar_signature=record["registrar_signature"],
        informant=informant,
    )


_cached_data = None
_cached_mtime = 0.0


def load_mock_data() -> dict:
    """Load mock birth records from mock_data.json located beside this module.

    The file is re-read and re-parsed only when its modification time changes,
    so edits to mock_data.json take effect without restarting the service while
    avoiding redundant I/O and object construction on every request. On a read
    or parse error the last successfully loaded data is served if available.
    """
    global _cached_data, _cached_mtime
    data_path = os.path.join(os.path.dirname(__file__), "mock_data.json")
    try:
        mtime = os.path.getmtime(data_path)
        if _cached_data is None or mtime > _cached_mtime:
            with open(data_path, "r", encoding="utf-8") as f:
                raw = json.load(f)
            _cached_data = {
                "birth": [_build_person(record) for record in raw["birth"]],
            }
            _cached_mtime = mtime
    except Exception:
        if _cached_data is not None:
            return _cached_data
        raise
    return _cached_data
