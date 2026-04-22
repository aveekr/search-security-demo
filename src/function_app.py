import azure.functions as func
import logging
import json
import os
import base64
from datetime import datetime, timezone
from azure.search.documents import SearchClient
from azure.storage.blob import BlobServiceClient
from azure.identity import DefaultAzureCredential
from shared.sql_client import get_advisor_by_identity, get_last_identity_lookup_error

app = func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)


def _decode_jwt_payload(token: str) -> dict:
    """Decode JWT payload without signature verification (APIM should validate token)."""
    try:
        parts = token.split('.')
        if len(parts) < 2:
            return {}

        payload_b64 = parts[1] + '=' * (-len(parts[1]) % 4)
        payload_json = base64.urlsafe_b64decode(payload_b64.encode('utf-8')).decode('utf-8')
        return json.loads(payload_json)
    except Exception:
        return {}


def _get_identity_claims(req: func.HttpRequest) -> dict:
    """Extract identity claims from Authorization bearer token."""
    auth_header = req.headers.get('Authorization', '')
    if not auth_header.lower().startswith('bearer '):
        return {}

    token = auth_header.split(' ', 1)[1].strip()
    claims = _decode_jwt_payload(token)

    return {
        "oid": claims.get("oid") or claims.get("sub"),
        "upn": claims.get("preferred_username") or claims.get("upn") or claims.get("email"),
        "name": claims.get("name")
    }


def _resolve_advisor_id(req: func.HttpRequest, requested_advisor_id: str = None) -> str:
    """Resolve advisor ID from request, identity map, or optional environment map."""
    if requested_advisor_id:
        return requested_advisor_id

    claims = _get_identity_claims(req)
    oid = claims.get("oid")
    upn = claims.get("upn")

    mapping = get_advisor_by_identity(oid, upn)
    if mapping and mapping.get("advisorId"):
        return mapping["advisorId"]

    # Optional fallback for quick demos without SQL mapping.
    # Format: {"user@contoso.com":"advisor-001"}
    env_map = os.getenv("USER_ADVISOR_MAP_JSON", "")
    if env_map and upn:
        try:
            parsed = json.loads(env_map)
            if isinstance(parsed, dict):
                return parsed.get(upn)
        except Exception:
            pass

    return None

def get_search_client() -> SearchClient:
    """Get Azure AI Search client"""
    search_endpoint = os.getenv("AZURE_SEARCH_ENDPOINT")
    index_name = os.getenv("SEARCH_INDEX_NAME", "capital-markets-docs")
    
    if not search_endpoint:
        raise ValueError("AZURE_SEARCH_ENDPOINT not set")
    
    credential = DefaultAzureCredential()
    return SearchClient(endpoint=search_endpoint, index_name=index_name, credential=credential)

@app.route(route="health", methods=["GET"])
def health_func(req: func.HttpRequest) -> func.HttpResponse:
    """Health check endpoint"""
    logging.info('Health check function triggered')
    return func.HttpResponse(
        json.dumps({"status": "healthy", "message": "Function app is running"}),
        status_code=200,
        mimetype="application/json"
    )

@app.route(route="search", methods=["POST"])
def search_func(req: func.HttpRequest) -> func.HttpResponse:
    """Vector and hybrid search with row-level security filtering"""
    logging.info('Search function triggered')
    
    try:
        req_body = req.get_json()
        query = req_body.get('query')
        advisor_id = req_body.get('advisorId')
        search_type = req_body.get('searchType', 'hybrid')
        top_k = req_body.get('top', 10)
        advisor_id = _resolve_advisor_id(req, advisor_id)
        
        if not query or not advisor_id:
            return func.HttpResponse(
                json.dumps({"error": "Missing required parameters: query and advisorId (or identity mapping)"}),
                status_code=400,
                mimetype="application/json"
            )
        
        # Get search client
        search_client = get_search_client()

        # Apply row-level access filtering by advisor.
        filter_expr = f"allowedAdvisors/any(a: a eq '{advisor_id}')"
        search_results = search_client.search(
            search_text=query,
            filter=filter_expr,
            top=top_k,
            include_total_count=True
        )

        documents = []
        for item in search_results:
            documents.append({
                "id": item.get("id"),
                "title": item.get("title"),
                "summary": item.get("summary"),
                "clientId": item.get("clientId"),
                "documentType": item.get("documentType"),
                "date": item.get("date")
            })

        results = {
            "results": documents,
            "count": search_results.get_count() if search_results.get_count() is not None else len(documents),
            "query": query,
            "advisorId": advisor_id,
            "searchType": search_type,
            "message": "Search completed"
        }
        
        return func.HttpResponse(
            json.dumps(results),
            status_code=200,
            mimetype="application/json"
        )
    except ValueError as e:
        logging.error(f"Validation error: {str(e)}")
        return func.HttpResponse(
            json.dumps({"error": str(e)}),
            status_code=400,
            mimetype="application/json"
        )
    except Exception as e:
        logging.error(f"Search error: {str(e)}")
        return func.HttpResponse(
            json.dumps({"error": "Internal server error", "details": str(e)}),
            status_code=500,
            mimetype="application/json"
        )


@app.route(route="me-context", methods=["GET"])
def me_context_func(req: func.HttpRequest) -> func.HttpResponse:
    """Resolve signed-in user identity to advisor context for UI/demo flows."""
    logging.info('Me context function triggered')

    try:
        claims = _get_identity_claims(req)
        oid = claims.get("oid")
        upn = claims.get("upn")

        identity_debug_enabled = os.getenv("ENABLE_IDENTITY_DEBUG", "false").lower() == "true"
        debug_requested = req.params.get("debug") == "1"

        mapping = get_advisor_by_identity(oid, upn)
        if not mapping:
            fallback_advisor_id = _resolve_advisor_id(req)
            if fallback_advisor_id:
                response = {
                    "authenticated": True,
                    "mapped": True,
                    "mappingSource": "env",
                    "oid": oid,
                    "upn": upn,
                    "name": claims.get("name"),
                    "advisorId": fallback_advisor_id
                }

                if identity_debug_enabled and debug_requested:
                    response["debug"] = {
                        "identityLookupError": get_last_identity_lookup_error(),
                        "claimsPresent": {
                            "oid": bool(oid),
                            "upn": bool(upn)
                        }
                    }

                return func.HttpResponse(
                    json.dumps(response),
                    status_code=200,
                    mimetype="application/json"
                )

            response = {
                "authenticated": bool(oid or upn),
                "mapped": False,
                "oid": oid,
                "upn": upn,
                "name": claims.get("name"),
                "message": "User not mapped to advisor. Add row in UserIdentityMap or USER_ADVISOR_MAP_JSON."
            }

            if identity_debug_enabled and debug_requested:
                response["debug"] = {
                    "identityLookupError": get_last_identity_lookup_error(),
                    "claimsPresent": {
                        "oid": bool(oid),
                        "upn": bool(upn)
                    }
                }

            return func.HttpResponse(
                json.dumps(response),
                status_code=404,
                mimetype="application/json"
            )

        response = {
            "authenticated": True,
            "mapped": True,
            "mappingSource": "sql",
            "oid": mapping.get("entraObjectId") or oid,
            "upn": mapping.get("userPrincipalName") or upn,
            "name": claims.get("name"),
            "advisorId": mapping.get("advisorId"),
            "advisorName": mapping.get("advisorName"),
            "advisorEmail": mapping.get("advisorEmail")
        }

        if identity_debug_enabled and debug_requested:
            response["debug"] = {
                "identityLookupError": get_last_identity_lookup_error(),
                "claimsPresent": {
                    "oid": bool(oid),
                    "upn": bool(upn)
                }
            }

        return func.HttpResponse(
            json.dumps(response),
            status_code=200,
            mimetype="application/json"
        )

    except Exception as e:
        logging.error(f"Me context error: {str(e)}")
        return func.HttpResponse(
            json.dumps({"error": str(e)}),
            status_code=500,
            mimetype="application/json"
        )

@app.route(route="documents", methods=["POST"])
def upload_func(req: func.HttpRequest) -> func.HttpResponse:
    """Upload a document with metadata and generate embeddings"""
    logging.info('Upload document function triggered')
    
    try:
        req_body = req.get_json()
        document_id = req_body.get('documentId')
        title = req_body.get('title')
        content = req_body.get('content')
        advisor_ids = req_body.get('advisorIds', [])
        
        if not all([document_id, title, content, advisor_ids]):
            return func.HttpResponse(
                json.dumps({"error": "Missing required parameters: documentId, title, content, advisorIds"}),
                status_code=400,
                mimetype="application/json"
            )
        
        client_id = req_body.get('clientId', 'UNKNOWN')
        document_type = req_body.get('documentType', 'general')

        # Generate summary
        summary = content[:200] + "..." if len(content) > 200 else content
        
        # Prepare document for indexing
        search_document = {
            "id": document_id,
            "title": title,
            "content": content,
            "summary": summary,
            "clientId": client_id,
            "documentType": document_type,
            "date": datetime.now(timezone.utc).isoformat(),
            "allowedAdvisors": advisor_ids
        }

        search_client = get_search_client()
        indexing_result = search_client.upload_documents(documents=[search_document])
        first_result = indexing_result[0] if indexing_result else None

        if not first_result or not getattr(first_result, "succeeded", False):
            logging.error(f"Indexing failed for document {document_id}")
            return func.HttpResponse(
                json.dumps({
                    "documentId": document_id,
                    "status": "failed",
                    "error": "Document indexing failed"
                }),
                status_code=500,
                mimetype="application/json"
            )

        logging.info(f"Document indexed successfully: {document_id}")
        
        return func.HttpResponse(
            json.dumps({
                "documentId": document_id,
                "status": "indexed",
                "title": title,
                "message": "Document indexed successfully"
            }),
            status_code=201,
            mimetype="application/json"
        )
    except Exception as e:
        logging.error(f"Upload error: {str(e)}")
        return func.HttpResponse(
            json.dumps({"error": str(e)}),
            status_code=500,
            mimetype="application/json"
        )

@app.route(route="documents/{document_id}", methods=["GET"])
def get_doc_func(req: func.HttpRequest) -> func.HttpResponse:
    """Get a specific document by ID with access control"""
    logging.info('Get document function triggered')
    
    try:
        document_id = req.route_params.get('document_id')
        advisor_id = req.params.get('advisorId')
        
        if not document_id or not advisor_id:
            return func.HttpResponse(
                json.dumps({"error": "Missing required parameters: document_id and advisorId"}),
                status_code=400,
                mimetype="application/json"
            )
        
        search_client = get_search_client()
        logging.info(f"Get document requested: {document_id} by {advisor_id}")

        document = search_client.get_document(key=document_id)
        allowed_advisors = document.get("allowedAdvisors", [])

        if advisor_id not in allowed_advisors:
            return func.HttpResponse(
                json.dumps({"error": "Document not found or access denied"}),
                status_code=404,
                mimetype="application/json"
            )
        
        return func.HttpResponse(
            json.dumps({
                "id": document.get("id"),
                "title": document.get("title"),
                "content": document.get("content"),
                "summary": document.get("summary"),
                "clientId": document.get("clientId"),
                "documentType": document.get("documentType"),
                "date": document.get("date"),
                "advisorId": advisor_id,
                "status": "ready",
                "message": "Document retrieved successfully"
            }),
            status_code=200,
            mimetype="application/json"
        )
    except Exception as e:
        logging.error(f"Get document error: {str(e)}")
        return func.HttpResponse(
            json.dumps({"error": str(e)}),
            status_code=500,
            mimetype="application/json"
        )
