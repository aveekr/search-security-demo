import os
import logging
from typing import Optional
from azure.search.documents import SearchClient
from azure.identity import DefaultAzureCredential

logger = logging.getLogger(__name__)

_search_client: Optional[SearchClient] = None


def get_search_client() -> SearchClient:
    """
    Get or create Azure AI Search client with managed identity
    
    Returns:
        SearchClient instance
    """
    global _search_client
    
    if _search_client is None:
        search_endpoint = os.getenv("AZURE_SEARCH_ENDPOINT")
        index_name = os.getenv("SEARCH_INDEX_NAME", "capital-markets-docs")
        
        if not search_endpoint:
            raise ValueError("AZURE_SEARCH_ENDPOINT environment variable not set")
        
        # Use DefaultAzureCredential for managed identity authentication
        credential = DefaultAzureCredential()
        
        _search_client = SearchClient(
            endpoint=search_endpoint,
            index_name=index_name,
            credential=credential
        )
        
        logger.info(f"Search client initialized for index: {index_name}")
    
    return _search_client
