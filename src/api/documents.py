import logging
import os
from typing import Dict, Any, List
from datetime import datetime
from azure.storage.blob import BlobServiceClient
from azure.identity import DefaultAzureCredential
from shared.search_client import get_search_client
from ared.embeddings import generate_embedding

logger = logging.getLogger(__name__)


def upload_document(document_data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Upload and index a document
    
    Args:
        document_data: Dictionary containing document metadata
            - title: Document title
            - content: Document content text
            - clientId: Client ID
            - documentType: Type of document
            - allowedAdvisors: List of advisor IDs who can access
    
    Returns:
        Dictionary with upload status
    """
    logger.info(f"Uploading document: {document_data.get('title')}")
    
    # Validate required fields
    required_fields = ['title', 'content', 'clientId', 'documentType', 'allowedAdvisors']
    for field in required_fields:
        if field not in document_data:
            raise ValueError(f"Missing required field: {field}")
    
    # Generate unique ID
    doc_id = f"doc-{datetime.utcnow().strftime('%Y%m%d%H%M%S')}-{document_data['clientId']}"
    
    # Generate summary (first 200 chars)
    summary = document_data['content'][:200] + "..." if len(document_data['content']) > 200 else document_data['content']
    
    # Generate embedding for content
    content_vector = generate_embedding(document_data['content'])
    
    # Prepare document for indexing
    search_document = {
        "id": doc_id,
        "title": document_data['title'],
        "content": document_data['content'],
        "summary": summary,
        "clientId": document_data['clientId'],
        "documentType": document_data['documentType'],
        "date": datetime.utcnow().isoformat(),
        "allowedAdvisors": document_data['allowedAdvisors'],  # Collection(Edm.String)
        "contentVector": content_vector
    }
    
    # Index document in Azure AI Search
    search_client = get_search_client()
    result = search_client.upload_documents(documents=[search_document])
    
    logger.info(f"Document indexed: {doc_id}")
    
    return {
        "documentId": doc_id,
        "status": "indexed",
        "title": document_data['title'],
        "clientId": document_data['clientId']
    }


def get_document(document_id: str, advisor_id: str) -> Dict[str, Any]:
    """
    Get document by ID with security check
    
    Args:
        document_id: Document ID
        advisor_id: Advisor ID requesting the document
    
    Returns:
        Document data or None if not found/unauthorized
    """
    logger.info(f"Getting document {document_id} for advisor {advisor_id}")
    
    search_client = get_search_client()
    
    try:
        # Get document
        document = search_client.get_document(key=document_id)
        
        # Check security: advisor must be in allowedAdvisors list
        allowed_advisors = document.get('allowedAdvisors', [])
        
        if advisor_id not in allowed_advisors:
            logger.warning(f"Advisor {advisor_id} not authorized for document {document_id}")
            return None
        
        return {
            "id": document.get("id"),
            "title": document.get("title"),
            "summary": document.get("summary"),
            "content": document.get("content"),
            "clientId": document.get("clientId"),
            "documentType": document.get("documentType"),
            "date": document.get("date"),
            "allowedAdvisors": allowed_advisors
        }
    
    except Exception as e:
        logger.error(f"Error getting document: {str(e)}")
        return None
