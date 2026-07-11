from typing import Protocol, List, Optional
from domain.entities.user import User
from interfaces.base_repository import Repository

class UserRepository(Repository[User], Protocol):
    def find_by_username(self, username: str) -> Optional[User]: ...
    def update_password(self, username: str, password_hash: str) -> bool: ...
