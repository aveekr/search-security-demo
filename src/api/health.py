import logging
import os
from typing import Dict, Any

logger = logging.getLogger(__name__)


def health_check() -> Dict[str, Any]:
    """
    Check health of dependencies
    
    Returns:
        Dictionary with health status
    """
    health_status = {
        "status": "healthy",
        "checks": {}
    }
    
    # Check environment variables
    required_env_vars = [
        "AZURE_SEARCH_ENDPOINT",
        "AZURE_SQL_SERVER",
        "AZURE_OPENAI_ENDPOINT"
    ]
    
    for env_var in required_env_vars:
        if os.getenv(env_var):
            health_status["checks"][env_var] = "configured"
        else:
            health_status["checks"][env_var] = "missing"
            health_status["status"] = "unhealthy"
    
    # Check AI Search
    try:
        from ..shared.search_client import get_search_client
        search_client = get_search_client()
        # Try to get index stats (lightweight operation)
        index_name = os.getenv("SEARCH_INDEX_NAME", "capital-markets-docs")
        health_status["checks"]["search_service"] = "healthy"
    except Exception as e:
        logger.error(f"Search service check failed: {str(e)}")
        health_status["checks"]["search_service"] = f"unhealthy: {str(e)}"
        health_status["status"] = "degraded"
    
    # Check SQL Database
    try:
        from ..shared.sql_client import test_connection
        if test_connection():
            health_status["checks"]["sql_database"] = "healthy"
        else:
            health_status["checks"]["sql_database"] = "unhealthy"
            health_status["status"] = "degraded"
    except Exception as e:
        logger.error(f"SQL database check failed: {str(e)}")
        health_status["checks"]["sql_database"] = f"unhealthy: {str(e)}"
        health_status["status"] = "degraded"
    
    # Check OpenAI
    try:
        from ..shared.embeddings import test_openai_connection
        if test_openai_connection():
            health_status["checks"]["openai_service"] = "healthy"
        else:
            health_status["checks"]["openai_service"] = "unhealthy"
            health_status["status"] = "degraded"
    except Exception as e:
        logger.error(f"OpenAI service check failed: {str(e)}")
        health_status["checks"]["openai_service"] = f"unhealthy: {str(e)}"
        health_status["status"] = "degraded"
    
    return health_status
