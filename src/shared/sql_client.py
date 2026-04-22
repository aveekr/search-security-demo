import os
import logging
import pyodbc
from typing import List, Optional, Dict, Any
from azure.identity import DefaultAzureCredential

logger = logging.getLogger(__name__)

_connection_string: Optional[str] = None
_last_identity_lookup_error: Optional[str] = None


def get_connection_string() -> str:
    """
    Get SQL connection string with managed identity
    
    Returns:
        Connection string
    """
    global _connection_string
    
    if _connection_string is None:
        server = os.getenv("AZURE_SQL_SERVER")
        database = os.getenv("AZURE_SQL_DATABASE")
        
        if not server or not database:
            raise ValueError("AZURE_SQL_SERVER and AZURE_SQL_DATABASE must be set")
        
        # Get access token for Azure SQL using managed identity
        credential = DefaultAzureCredential()
        token = credential.get_token("https://database.windows.net/.default")
        
        # Connection string with access token
        _connection_string = (
            f"Driver={{ODBC Driver 18 for SQL Server}};"
            f"Server=tcp:{server},1433;"
            f"Database={database};"
            f"Encrypt=yes;"
            f"TrustServerCertificate=no;"
            f"Connection Timeout=30;"
        )
        
        logger.info(f"SQL connection string configured for {server}/{database}")
    
    return _connection_string


def _get_token_struct() -> bytearray:
    """Build the AAD access token structure expected by ODBC driver."""
    credential = DefaultAzureCredential()
    token_bytes = credential.get_token("https://database.windows.net/.default").token.encode("UTF-16-LE")

    token_struct = bytearray()
    token_struct.extend(bytearray([0x01, 0x00]))
    token_struct.extend(bytearray(len(token_bytes).to_bytes(2, byteorder="little")))
    token_struct.extend(token_bytes)
    return token_struct


def get_allowed_clients(advisor_id: str) -> List[str]:
    """
    Get list of client IDs that an advisor has access to
    
    Args:
        advisor_id: Advisor ID
    
    Returns:
        List of client IDs
    """
    logger.info(f"Getting allowed clients for advisor {advisor_id}")
    
    try:
        token_struct = _get_token_struct()
        
        conn_str = get_connection_string()
        
        with pyodbc.connect(conn_str, attrs_before={1256: token_struct}) as conn:
            cursor = conn.cursor()
            
            query = """
                SELECT c.ClientId
                FROM AdvisorClientAccess aca
                INNER JOIN Clients c ON aca.ClientId = c.Id
                WHERE aca.AdvisorId = (SELECT Id FROM Advisors WHERE AdvisorId = ?)
                  AND aca.IsActive = 1
            """
            
            cursor.execute(query, (advisor_id,))
            rows = cursor.fetchall()
            
            client_ids = [row.ClientId for row in rows]
            logger.info(f"Found {len(client_ids)} clients for advisor {advisor_id}")
            
            return client_ids
    
    except Exception as e:
        logger.error(f"Error getting allowed clients: {str(e)}")
        raise


def get_advisor_by_identity(object_id: Optional[str], user_principal_name: Optional[str]) -> Optional[Dict[str, Any]]:
    """
    Resolve advisor mapping from identity claims.

    Args:
        object_id: Entra object id (oid claim)
        user_principal_name: UPN/email claim

    Returns:
        Mapping record with advisorId and identity details, or None.
    """
    global _last_identity_lookup_error

    # Reset last error for every lookup attempt.
    _last_identity_lookup_error = None

    if not object_id and not user_principal_name:
        return None

    try:
        token_struct = _get_token_struct()
        conn_str = get_connection_string()

        with pyodbc.connect(conn_str, attrs_before={1256: token_struct}) as conn:
            cursor = conn.cursor()

            query = """
                SELECT TOP 1
                    uim.EntraObjectId,
                    uim.UserPrincipalName,
                    uim.AdvisorId,
                    a.FirstName,
                    a.LastName,
                    a.Email
                FROM UserIdentityMap uim
                LEFT JOIN Advisors a ON a.AdvisorId = uim.AdvisorId
                WHERE uim.IsActive = 1
                  AND (
                       (? IS NOT NULL AND uim.EntraObjectId = ?)
                    OR (? IS NOT NULL AND LOWER(uim.UserPrincipalName) = LOWER(?))
                  )
            """

            cursor.execute(query, (object_id, object_id, user_principal_name, user_principal_name))
            row = cursor.fetchone()
            if not row:
                return None

            return {
                "entraObjectId": row.EntraObjectId,
                "userPrincipalName": row.UserPrincipalName,
                "advisorId": row.AdvisorId,
                "advisorName": f"{row.FirstName or ''} {row.LastName or ''}".strip(),
                "advisorEmail": row.Email
            }

    except Exception as e:
        _last_identity_lookup_error = str(e)
        logger.error(f"Error resolving advisor by identity: {str(e)}")
        return None


def get_last_identity_lookup_error() -> Optional[str]:
    """Return the most recent identity lookup error, if any."""
    return _last_identity_lookup_error


def test_connection() -> bool:
    """
    Test SQL database connection
    
    Returns:
        True if connection successful
    """
    try:
        token_struct = _get_token_struct()
        
        conn_str = get_connection_string()
        
        with pyodbc.connect(conn_str, attrs_before={1256: token_struct}) as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT 1")
            cursor.fetchone()
            return True
    
    except Exception as e:
        logger.error(f"SQL connection test failed: {str(e)}")
        return False
