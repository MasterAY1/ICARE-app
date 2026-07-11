class DatabaseConnectionError(Exception):
    """Raised when the database connection fails."""
    pass

class RepositoryError(Exception):
    """Base exception for repository operations."""
    pass

class DuplicateRecordError(RepositoryError):
    """Raised when a constraint violation occurs."""
    pass

class NotFoundError(RepositoryError):
    """Raised when a requested entity is not found."""
    pass
