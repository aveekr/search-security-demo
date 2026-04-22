import azure.functions as func
import logging
import json
from .search import search_documents
from .documents import upload_document, get_document
from .health import health_check

app = func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)

@app.route(route="search", methods=["POST"])
def search(req: func.HttpRequest) -> func.HttpResponse:
    """
    Vector and hybrid search with security filtering
    """
    logging.info('Search function triggered')
    
    try:
        req_body = req.get_json()
        query = req_body.get('query')
        advisor_id = req_body.get('advisorId')
        search_type = req_body.get('searchType', 'hybrid')
        top_k = req_body.get('top', 10)
        
        if not query or not advisor_id:
            return func.HttpResponse(
                json.dumps({
                    "error": "Missing required parameters: query and advisorId"
                }),
                status_code=400,
                mimetype="application/json"
            )
        
        results = search_documents(query, advisor_id, search_type, top_k)
        
        return func.HttpResponse(
            json.dumps(results, default=str),
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
        logging.error(f"Error in search: {str(e)}")
        return func.HttpResponse(
            json.dumps({"error": "Internal server error"}),
            status_code=500,
            mimetype="application/json"
        )


@app.route(route="documents", methods=["POST"])
def upload(req: func.HttpRequest) -> func.HttpResponse:
    """
    Upload and index a document
    """
    logging.info('Upload function triggered')
    
    try:
        req_body = req.get_json()
        result = upload_document(req_body)
        
        return func.HttpResponse(
            json.dumps(result),
            status_code=201,
            mimetype="application/json"
        )
    
    except Exception as e:
        logging.error(f"Error uploading document: {str(e)}")
        return func.HttpResponse(
            json.dumps({"error": str(e)}),
            status_code=500,
            mimetype="application/json"
        )


@app.route(route="documents/{document_id}", methods=["GET"])
def get_doc(req: func.HttpRequest) -> func.HttpResponse:
    """
    Get document metadata by ID
    """
    logging.info('Get document function triggered')
    
    try:
        document_id = req.route_params.get('document_id')
        advisor_id = req.params.get('advisorId')
        
        if not advisor_id:
            return func.HttpResponse(
                json.dumps({"error": "Missing advisorId parameter"}),
                status_code=400,
                mimetype="application/json"
            )
        
        result = get_document(document_id, advisor_id)
        
        if result:
            return func.HttpResponse(
                json.dumps(result, default=str),
                status_code=200,
                mimetype="application/json"
            )
        else:
            return func.HttpResponse(
                json.dumps({"error": "Document not found or access denied"}),
                status_code=404,
                mimetype="application/json"
            )
    
    except Exception as e:
        logging.error(f"Error getting document: {str(e)}")
        return func.HttpResponse(
            json.dumps({"error": str(e)}),
            status_code=500,
            mimetype="application/json"
        )


@app.route(route="health", methods=["GET"])
def health(req: func.HttpRequest) -> func.HttpResponse:
    """
    Health check endpoint
    """
    logging.info('Health check triggered')
    
    try:
        status = health_check()
        
        if status["status"] == "healthy":
            return func.HttpResponse(
                json.dumps(status),
                status_code=200,
                mimetype="application/json"
            )
        else:
            return func.HttpResponse(
                json.dumps(status),
                status_code=503,
                mimetype="application/json"
            )
    
    except Exception as e:
        logging.error(f"Health check failed: {str(e)}")
        return func.HttpResponse(
            json.dumps({
                "status": "unhealthy",
                "error": str(e)
            }),
            status_code=503,
            mimetype="application/json"
        )
