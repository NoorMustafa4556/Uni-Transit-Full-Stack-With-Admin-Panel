from django.db.backends.signals import connection_created
from django.dispatch import receiver

@receiver(connection_created)
def set_sqlite_pragma(sender, connection, **kwargs):
    """
    Enforces WAL (Write-Ahead-Logging) and concurrency settings for SQLite3.
    """
    if connection.vendor == 'sqlite':
        cursor = connection.cursor()
        cursor.execute('PRAGMA journal_mode=WAL;')
        cursor.execute('PRAGMA synchronous=NORMAL;')
        cursor.execute('PRAGMA busy_timeout=20000;')
        cursor.execute('PRAGMA foreign_keys=ON;')
