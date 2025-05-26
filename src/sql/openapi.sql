SET ROLE witstats_owner;

-- OpenAPI specification provider
CREATE OR REPLACE FUNCTION witstats_api.home()
RETURNS JSONB AS $function$
BEGIN
  RETURN $json${
    "openapi": "3.0.3",
    "info": {
      "title": "Witness Reward Stats",
      "description": "API for witness reward statistics",
      "version": "1.27.11"
    },
    "servers": [
      { "url": "/witreward-api" }
    ],
    "paths": {
      "/totals/{producer}": {
        "get": {
          "summary": "Get total rewards for a witness",
          "parameters": [
            {
              "name": "producer",
              "in": "path",
              "required": true,
              "schema": {
                "type": "string",
                "description": "Witness username"
              }
            }
          ],
          "responses": {
            "200": {
              "description": "Successful response",
              "content": {
                "application/json": {
                  "schema": {
                    "type": "object",
                    "properties": {
                      "total_vests": {
                        "type": "string",
                        "description": "Total VESTS produced"
                      },
                      "total_hive": {
                        "type": "string",
                        "description": "Total equivalent staked HIVE produced at the time of production"
                      },
                      "total_blocks": {
                        "type": "integer",
                        "description": "Total blocks produced"
                      }
                    }
                  }
                }
              }
            },
            "400": {"$ref": "#/components/responses/BadRequest"},
            "404": {"$ref": "#/components/responses/ProducerNotFound"}
          }
        }
      },
      "/history/{producer}": {
        "get": {
          "summary": "Get reward history for a witness",
          "parameters": [
            {
              "name": "producer",
              "in": "path",
              "required": true,
              "schema": {
                "type": "string",
                "description": "Witness username"
              }
            },
            {
              "name": "start_date",
              "in": "query",
              "schema": {
                "type": "string",
                "format": "date-time",
                "description": "Start date for history (format: 'YYYY-MM-DD')"
              }
            },
            {
              "name": "end_date",
              "in": "query",
              "schema": {
                "type": "string",
                "format": "date-time",
                "description": "End date for history (format: 'YYYY-MM-DD')"
              }
            },
            {
              "name": "direction",
              "in": "query",
              "schema": {
                "type": "string",
                "enum": ["asc", "desc"],
                "default": "asc",
                "description": "Sorting direction"
              }
            },
            {
              "name": "granularity",
              "in": "query",
              "schema": {
                "type": "string",
                "enum": ["daily", "monthly", "yearly"],
                "default": "daily",
                "description": "Time interval aggregation"
              }
            }
          ],
          "responses": {
            "200": {
              "description": "Successful response",
              "content": {
                "application/json": {
                  "schema": {
                    "type": "array",
                    "items": {
                      "type": "object",
                      "properties": {
                        "date": {
                          "type": "string",
                          "format": "date"
                        },
                        "vests": {"type": "string"},
                        "hive": {"type": "string"},
                        "count": {"type": "integer"}
                      }
                    }
                  }
                }
              }
            },
            "400": {"$ref": "#/components/responses/BadRequest"},
            "404": {"$ref": "#/components/responses/ProducerNotFound"}
          }
        }
      },
      "/last-synced-block": {
        "get": {
          "summary": "Get latest synced block number",
          "responses": {
            "200": {
              "description": "Latest block number",
              "content": {
                "application/json": {"schema": {"type": "integer"}}
              }
            },
            "503": {"$ref": "#/components/responses/ServiceUnavailable"}
          }
        }
      }
    },
    "components": {
      "responses": {
        "BadRequest": {"description": "Invalid request parameters"},
        "ProducerNotFound": {"description": "Specified witness does not exist"},
        "ServiceUnavailable": {"description": "Witness reward stats API unavailable"}
      }
    }
  }$json$::JSONB;
END;
$function$
LANGUAGE plpgsql STABLE;
