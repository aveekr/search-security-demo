"""
Upload sample documents to Azure AI Search index.

This script loads JSON documents from the data/documents directory
and uploads them to the search index using the Function App API.
"""

import json
import os
import requests
from pathlib import Path
from typing import Dict, List, Tuple
import time

# Configuration (prefer environment variables)
# APIM mode (OAuth bearer token):
#   APIM_GATEWAY_URL=https://<apim>.azure-api.net
#   ACCESS_TOKEN=<bearer-token>
# Function App mode (function key auth):
#   FUNCTION_APP_URL=https://<func>.azurewebsites.net
#   FUNCTION_KEY=<function-key>
APIM_GATEWAY_URL = os.getenv("APIM_GATEWAY_URL", "").rstrip("/")
ACCESS_TOKEN = os.getenv("ACCESS_TOKEN", "")
FUNCTION_APP_URL = os.getenv("FUNCTION_APP_URL", "https://aisearch-demo-func-wyjsbl.azurewebsites.net").rstrip("/")
FUNCTION_KEY = os.getenv("FUNCTION_KEY", "")

DOCUMENTS_DIR = Path(__file__).parent.parent / "data" / "documents"


def get_access_token(tenant_id: str, client_id: str, client_secret: str) -> str:
    """
    Obtain OAuth 2.0 access token from Microsoft Entra ID.
    
    Args:
        tenant_id: Azure AD tenant ID
        client_id: Application (client) ID
        client_secret: Client secret
        
    Returns:
        Access token string
    """
    token_url = f"https://login.microsoftonline.com/{tenant_id}/oauth2/v2.0/token"
    
    data = {
        "client_id": client_id,
        "client_secret": client_secret,
        "scope": f"{client_id}/.default",
        "grant_type": "client_credentials"
    }
    
    response = requests.post(token_url, data=data)
    response.raise_for_status()
    
    return response.json()["access_token"]


def load_documents() -> List[Dict]:
    """
    Load all JSON documents from the documents directory.
    
    Returns:
        List of document dictionaries
    """
    documents = []
    
    for file_path in sorted(DOCUMENTS_DIR.glob("*.json")):
        print(f"Loading {file_path.name}...")
        with open(file_path, 'r', encoding='utf-8') as f:
            doc = json.load(f)
            # Ensure each document has an explicit ID for the current API contract.
            if not doc.get("documentId"):
                doc["documentId"] = file_path.stem
            documents.append(doc)
    
    return documents


def build_upload_target() -> Tuple[str, Dict[str, str], Dict[str, str]]:
    """
    Build endpoint, headers and query params based on auth mode.

    Returns:
        (endpoint, headers, params)
    """
    if APIM_GATEWAY_URL:
        if not ACCESS_TOKEN:
            raise ValueError("APIM_GATEWAY_URL is set but ACCESS_TOKEN is missing")

        endpoint = f"{APIM_GATEWAY_URL}/documents"
        headers = {
            "Authorization": f"Bearer {ACCESS_TOKEN}",
            "Content-Type": "application/json"
        }
        return endpoint, headers, {}

    if not FUNCTION_APP_URL:
        raise ValueError("Set FUNCTION_APP_URL or APIM_GATEWAY_URL")

    if not FUNCTION_KEY:
        raise ValueError("FUNCTION_KEY is required when using FUNCTION_APP_URL")

    endpoint = f"{FUNCTION_APP_URL}/api/documents"
    headers = {"Content-Type": "application/json"}
    params = {"code": FUNCTION_KEY}
    return endpoint, headers, params


def to_api_payload(document: Dict) -> Dict:
    """Map sample document schema to current Function API schema."""
    return {
        "documentId": document.get("documentId"),
        "title": document.get("title"),
        "content": document.get("content"),
        "advisorIds": document.get("allowedAdvisors", []),
        "clientId": document.get("clientId", "UNKNOWN"),
        "documentType": document.get("documentType", "general")
    }


def upload_document(document: Dict, endpoint: str, headers: Dict[str, str], params: Dict[str, str]) -> Dict:
    """
    Upload a single document to the search index.
    
    Args:
        document: Document dictionary with title, content, etc.
        token: OAuth access token
        
    Returns:
        Upload response
    """
    payload = to_api_payload(document)

    response = requests.post(
        endpoint,
        headers=headers,
        params=params,
        json=payload,
        timeout=30
    )
    
    response.raise_for_status()
    return response.json()


def main():
    """Main execution function."""
    
    try:
        endpoint, headers, params = build_upload_target()
    except ValueError as e:
        print(f"ERROR: {str(e)}")
        print("\nExamples:")
        print("  $env:FUNCTION_APP_URL='https://aisearch-demo-func-wyjsbl.azurewebsites.net'")
        print("  $env:FUNCTION_KEY='<your-function-key>'")
        print("  python upload_documents.py")
        return

    mode = "APIM+OAuth" if APIM_GATEWAY_URL else "FunctionApp+Key"
    print(f"Auth mode: {mode}")
    print(f"Upload endpoint: {endpoint}")
    
    # Load documents
    print(f"\nLoading documents from {DOCUMENTS_DIR}...")
    documents = load_documents()
    print(f"Loaded {len(documents)} documents\n")
    
    # Upload documents
    success_count = 0
    error_count = 0
    
    for i, doc in enumerate(documents, 1):
        try:
            print(f"[{i}/{len(documents)}] Uploading: {doc['title'][:60]}...")
            result = upload_document(doc, endpoint, headers, params)
            print(f"  ✓ Success - Document ID: {result.get('documentId', doc.get('documentId', 'N/A'))}")
            success_count += 1
            
            # Rate limiting - small delay between uploads
            time.sleep(0.5)
            
        except requests.exceptions.HTTPError as e:
            print(f"  ✗ HTTP Error: {e.response.status_code} - {e.response.text}")
            error_count += 1
        except Exception as e:
            print(f"  ✗ Error: {str(e)}")
            error_count += 1
    
    # Summary
    print(f"\n{'='*60}")
    print(f"Upload Summary:")
    print(f"  Total documents: {len(documents)}")
    print(f"  Successful: {success_count}")
    print(f"  Failed: {error_count}")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
