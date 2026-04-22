import logging
import os
from typing import List, Dict, Any
from azure.search.documents import SearchClient
from azure.search.documents.models import VectorizedQuery
from azure.core.credentials import AzureKeyCredential
from azure.identity import DefaultAzureCredential
from shared.search_client import get_search_client
from shared.sql_client import get_allowed_clients
from shared.embeddings import generate_embedding

logger = logging.getLogger(__name__)


def search_documents(
    query: str,
    advisor_id: str,
    search_type: str = "hybrid",
    top_k: int = 10
) -> Dict[str, Any]:
    """
    Search documents with security filtering
    
    Args:
        query: Search query text
        advisor_id: Advisor ID for security filtering
        search_type: "vector", "keyword", or "hybrid"
        top_k: Number of results to return
    
    Returns:
        Dictionary with search results and metadata
    """
    logger.info(f"Searching for '{query}' with advisor {advisor_id}, type={search_type}")
    
    # Get search client
    search_client = get_search_client()
    
    # Get allowed clients for this advisor
    allowed_clients = get_allowed_clients(advisor_id)
    logger.info(f"Advisor {advisor_id} has access to {len(allowed_clients)} clients")
    
    if not allowed_clients:
        logger.warning(f"Advisor {advisor_id} has no client access")
        return {
            "results": [],
            "count": 0,
            "message": "No accessible documents found"
        }
    
    # Build security filter
    # Filter format: search.in(allowedAdvisors, 'advisor-001,advisor-002', ',')
    security_filter = f"search.in(allowedAdvisors, '{advisor_id}', ',')"
    
    logger.info(f"Applying security filter: {security_filter}")
    
    try:
        if search_type == "vector":
            # Pure vector search
            results = _vector_search(search_client, query, security_filter, top_k)
        elif search_type == "keyword":
            # Pure keyword search
            results = _keyword_search(search_client, query, security_filter, top_k)
        else:
            # Hybrid search (default)
            results = _hybrid_search(search_client, query, security_filter, top_k)
        
        return {
            "results": results,
            "count": len(results),
            "searchType": search_type,
            "advisorId": advisor_id,
            "query": query
        }
    
    except Exception as e:
        logger.error(f"Search error: {str(e)}")
        raise


def _vector_search(
    search_client: SearchClient,
    query: str,
    security_filter: str,
    top_k: int
) -> List[Dict[str, Any]]:
    """
    Pure vector semantic search
    """
    logger.info("Performing vector search")
    
    # Generate embedding for query
    query_vector = generate_embedding(query)
    
    # Create vectorized query
    vector_query = VectorizedQuery(
        vector=query_vector,
        k_nearest_neighbors=top_k,
        fields="contentVector"
    )
    
    # Execute search
    results = search_client.search(
        search_text=None,  # No keyword search
        vector_queries=[vector_query],
        filter=security_filter,
        select=["id", "title", "content", "clientId", "documentType", "date", "summary"],
        top=top_k
    )
    
    return _format_results(results)


def _keyword_search(
    search_client: SearchClient,
    query: str,
    security_filter: str,
    top_k: int
) -> List[Dict[str, Any]]:
    """
    Pure keyword full-text search
    """
    logger.info("Performing keyword search")
    
    results = search_client.search(
        search_text=query,
        filter=security_filter,
        select=["id", "title", "content", "clientId", "documentType", "date", "summary"],
        top=top_k
    )
    
    return _format_results(results)


def _hybrid_search(
    search_client: SearchClient,
    query: str,
    security_filter: str,
    top_k: int
) -> List[Dict[str, Any]]:
    """
    Hybrid search combining vector and keyword search
    """
    logger.info("Performing hybrid search")
    
    # Generate embedding for query
    query_vector = generate_embedding(query)
    
    # Create vectorized query
    vector_query = VectorizedQuery(
        vector=query_vector,
        k_nearest_neighbors=top_k,
        fields="contentVector"
    )
    
    # Execute hybrid search
    results = search_client.search(
        search_text=query,  # Keyword component
        vector_queries=[vector_query],  # Vector component
        filter=security_filter,
        select=["id", "title", "content", "clientId", "documentType", "date", "summary"],
        top=top_k,
        query_type="semantic",  # Enable semantic ranking
        semantic_configuration_name="default"
    )
    
    return _format_results(results)


def _format_results(results) -> List[Dict[str, Any]]:
    """
    Format search results into JSON-serializable format
    """
    formatted = []
    
    for result in results:
        formatted.append({
            "id": result.get("id"),
            "title": result.get("title"),
            "summary": result.get("summary"),
            "content": result.get("content", "")[:500],  # Truncate content
            "clientId": result.get("clientId"),
            "documentType": result.get("documentType"),
            "date": result.get("date"),
            "score": result.get("@search.score"),
            "rerankerScore": result.get("@search.reranker_score")
        })
    
    return formatted
