import os
import logging
from typing import List
from openai import AzureOpenAI
from azure.identity import DefaultAzureCredential, get_bearer_token_provider

logger = logging.getLogger(__name__)

_openai_client = None


def get_openai_client() -> AzureOpenAI:
    """
    Get or create Azure OpenAI client with managed identity
    
    Returns:
        AzureOpenAI client
    """
    global _openai_client
    
    if _openai_client is None:
        endpoint = os.getenv("AZURE_OPENAI_ENDPOINT")
        api_version = os.getenv("OPENAI_API_VERSION", "2024-02-01")
        
        if not endpoint:
            raise ValueError("AZURE_OPENAI_ENDPOINT must be set")
        
        # Use managed identity for authentication
        credential = DefaultAzureCredential()
        token_provider = get_bearer_token_provider(
            credential,
            "https://cognitiveservices.azure.com/.default"
        )
        
        _openai_client = AzureOpenAI(
            azure_endpoint=endpoint,
            azure_ad_token_provider=token_provider,
            api_version=api_version
        )
        
        logger.info("OpenAI client initialized with managed identity")
    
    return _openai_client


def generate_embedding(text: str) -> List[float]:
    """
    Generate embedding vector for text
    
    Args:
        text: Input text
    
    Returns:
        List of floats representing the embedding vector
    """
    client = get_openai_client()
    deployment_name = os.getenv("OPENAI_EMBEDDING_DEPLOYMENT", "text-embedding-ada-002")
    
    try:
        response = client.embeddings.create(
            input=text,
            model=deployment_name
        )
        
        embedding = response.data[0].embedding
        logger.debug(f"Generated embedding of dimension {len(embedding)}")
        
        return embedding
    
    except Exception as e:
        logger.error(f"Error generating embedding: {str(e)}")
        raise


def test_openai_connection() -> bool:
    """
    Test OpenAI service connection
    
    Returns:
        True if connection successful
    """
    try:
        client = get_openai_client()
        # Try to generate a simple embedding
        response = client.embeddings.create(
            input="test",
            model=os.getenv("OPENAI_EMBEDDING_DEPLOYMENT", "text-embedding-ada-002")
        )
        return len(response.data) > 0
    
    except Exception as e:
        logger.error(f"OpenAI connection test failed: {str(e)}")
        return False
