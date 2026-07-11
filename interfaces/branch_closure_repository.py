from typing import Protocol, List
from domain.entities.branch_closure import BranchClosure
from interfaces.base_repository import Repository

class BranchClosureRepository(Repository[BranchClosure], Protocol):
    def find_all(self) -> List[BranchClosure]: ...
