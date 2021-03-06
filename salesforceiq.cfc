component output="false" displayname="SalesforceIQ.cfc"  {

  variables.utcBaseDate = dateAdd( "l", createDate( 1970,1,1 ).getTime() * -1, createDate( 1970,1,1 ) );
  variables.integerFields = [ "_start", "_limit" ];
  variables.numericFields = [  ];
  variables.timestampFields = [ "_modifiedDate", "modifiedDate", "createdDate" ];
  variables.booleanFields = [  ];
  variables.arrayFields = [ "_ids", "contactIds" ];
  variables.fileFields = [  ];
  variables.dictionaryFields = {
  	newAccount = { required = [ "name" ], optional = [ ] },
    updatedAccount = { required = [ "id", "name" ], optional = [ ] },
  	newContact = { required = [ "properties" ], optional = [ ] },
    updatedContact = { required = [ "id", "properties" ], optional = [ ] },
    newListItem = { required = [ "listId" ], optional = [ "accountId", "contactIds", "name", "fieldValues", "linkedItemIds" ] },
    updatedListItem = { required = [ "id", "listId" ], optional = [ "accountId", "contactIds", "name", "fieldValues", "linkedItemIds" ] },
    properties = { required = [ "email" ], optional = [ "name", "phone", "address", "company", "title" ] },
    fieldValues = { required = [ ], optional = [  ] }
  };

  public any function init( required string apiKey, required string apiSecret, string baseUrl = "https://api.salesforceiq.com/v2", numeric httpTimeout = 60, boolean includeRaw = true ) {

    structAppend( variables, arguments );

    var lists = listLists();
    for ( var list in lists.objects ) {
      for ( var field in list.fields ) {

        if ( field.dataType == "Numeric" && !arrayFindNoCase( variables.numericFields, field.id ) ) {
          arrayAppend(variables.numericFields, field.id);
        } else if ( field.dataType == 'List' && !arrayFindNoCase( variables.arrayFields, field.id ) ) {
          arrayAppend(variables.arrayFields, field.id);
        } else if ( field.dataType == 'DateTime' && !arrayFindNoCase( variables.timestampFields, field.id ) ) {
          arrayAppend(variables.timestampFields, field.id);
        } else if ( field.dataType == 'File' && !arrayFindNoCase( variables.fileFields, field.id ) ) {
          arrayAppend(variables.fileFields, field.id);
        }

        if ( !arrayFindNoCase( variables.dictionaryFields.fieldValues.optional, field.id ) ) {
          arrayAppend(variables.dictionaryFields.fieldValues.optional, field.id);
        }
      }
    }

    return this;
  }

  //ACCOUNTS
  public struct function createAccount( required struct newAccount ) {

    return apiCall( "/accounts", setupParams( arguments ), "post" );
  }

  public struct function updateAccount( required string accountId, required struct updatedAccount ) {

    return apiCall( "/accounts/#trim( accountId )#", setupParams( arguments, ["accountId"] ), "put" );
  }

  public struct function getAccount( required string accountId ) {

    return apiCall( "/accounts/#trim( accountId )#", setupParams( {} ), "get" );
  }

  public struct function listAccounts( array _ids, numeric _start = "0", numeric _limit = "50", string _modifiedDate   ) {

    return apiCall( "/accounts", setupParams( arguments ), "get" );
  }

  //CONTACTS
  public struct function createContact( required struct newContact ) {

    return apiCall( "/contacts", setupParams( arguments ), "post" );
  }

  public struct function upsertContact( required struct newContact ) {

    return apiCall( "/contacts?_upsert=email", setupParams( arguments ), "post" );
  }

  public struct function updateContact( required string contactId, required struct updatedContact ) {

    return apiCall( "/contacts/#trim( contactId )#", setupParams( arguments, ["contactId"] ), "put" );
  }

  public struct function getContact( required string contactId ) {

    return apiCall( "/contacts/#trim( contactId )#", setupParams( {} ), "get" );
  }

  public struct function listContacts( array _ids, numeric _start = "0", numeric _limit = "20", string _modifiedDate   ) {

    return apiCall( "/contacts", setupParams( arguments ), "get" );
  }

  //LISTS
  public struct function getList( required string listId ) {

    return apiCall( "/lists/#trim( listId )#", setupParams( {} ), "get" );
  }

  public struct function listLists( array _ids, numeric _start = "0", numeric _limit = "20" ) {

    return apiCall( "/lists", setupParams( arguments ), "get" );
  }

  //LIST ITEMS
  public struct function createListItem( required string listId, required struct newListItem ) {

    return apiCall( "/lists/#trim( listId )#/listitems", setupParams( arguments, ["listId"] ), "post" );
  }

  public struct function upsertListItem( required string listId, required struct newListItem, required string upsertType ) {

    return apiCall( "/lists/#trim( listId )#/listitems?_upsert=#upsertType#", setupParams( arguments, ["listId", "upsertType"] ), "post" );
  }

  public struct function updateListItem( required string listId, required string itemId, required struct updatedListItem ) {

    return apiCall( "/lists/#trim( listId )#/listitems/#trim( itemId )#", setupParams( arguments, ["listId", "itemId"] ), "put" );
  }

  public struct function getListItem( required string listId, required string itemId ) {

    return apiCall( "/lists/#trim( listId )#/listitems/#trim( itemId )#", setupParams( {} ), "get" );
  }

  public struct function deleteListItem( required string listId, required string itemId ) {

    return apiCall( "/lists/#trim( listId )#/listitems/#trim( itemId )#", setupParams( {} ), "delete" );
  }

  public struct function listListItems( required string listId, array _ids, numeric _start = "0", numeric _limit = "20", string _modifiedDate ) {

    return apiCall( "/lists/#trim( listId )#/listitems", setupParams( arguments, ["listId"] ), "get" );
  }

  //FIELDS
  public struct function listAccountFields( ) {

    return apiCall( "/accounts/fields", setupParams( {} ), "get" );
  }

  // PRIVATE FUNCTIONS
  private struct function apiCall( required string path, struct params = { }, string method = "get" )  {

    var fullApiPath = variables.baseUrl & path;
    var requestStart = getTickCount();


    var apiResponse = makeHttpRequest( urlPath = fullApiPath, params = params, method = method );

    var result = { "api_request_time" = getTickCount() - requestStart, "status_code" = listFirst( apiResponse.statuscode, " " ), "status_text" = listRest( apiResponse.statuscode, " " ) };
    if ( variables.includeRaw ) {
      result[ "raw" ] = { "method" = ucase( method ), "path" = fullApiPath, "params" = serializeJSON( params ), "response" = apiResponse.fileContent };
    }

    structAppend(  result, isBoolean( apiResponse.fileContent ) ? { "response" : apiResponse.fileContent } : deserializeJSON( apiResponse.fileContent ), true );
    parseResult( result );
    return result;
  }

  private any function makeHttpRequest( required string urlPath, required struct params, required string method ) {
    var http = new http( url = urlPath, method = method, username = variables.apiKey, password = variables.apiSecret, timeout = variables.httpTimeout );

    // adding a user agent header so that Adobe ColdFusion doesn't get mad about empty HTTP posts
    http.addParam( type = "header", name = "User-Agent", value = "salesforceIQ.cfc" );

    var qs = [ ];

    for ( var param in params ) {

      if ( arrayFind( [ "post","put" ], method ) ) {
        if ( arraycontains( variables.fileFields , param ) ) {
          http.addParam( type = "file", name = lcase( param ), file = param[param] );
        }
      } else if ( arrayFind( [ "get","delete" ], method ) ) {
        arrayAppend( qs, lcase( param ) & "=" & encodeurl( params[param] ) );
      }

    }

    if ( arrayFind( [ "post","put" ], method ) ) {
    	http.addParam( type = "header", name = "Content-Type", value = "application/json" );
    	http.addParam( type = "body", value = serializeJSON( params[structkeylist(params)] ) );
    }

    if ( arrayLen( qs ) ) {
      http.setUrl( urlPath & "?" & arrayToList( qs, "&" ) );
    }

    return http.send().getPrefix();
  }

  private struct function setupParams( required struct params, array prune = [] ) {
    var filteredParams = { };
    //gets the keys of the struct (argument names)
    var paramKeys = structKeyArray( params );
    for ( var paramKey in paramKeys ) {
      if ( structKeyExists( params, paramKey ) && !isNull( params[ paramKey ] ) && !ArrayFindNoCase(prune, paramKey) ) {
        filteredParams[ paramKey ] = params[ paramKey ];
      }
    }

    //is this the point where I separate the objects from the other types of fields?

    return parseDictionary( filteredParams );
  }

  private struct function parseDictionary( required struct dictionary, string name = '' ) {
    var result = { };
    var structFieldExists = structKeyExists( variables.dictionaryFields, name );

    // validate required dictionary keys based on variables.dictionaries
    if ( structFieldExists ) {
      for ( var field in variables.dictionaryFields[ name ].required ) {
        if ( !structKeyExists( dictionary, field ) ) {
          throwError( "'#name#' dictionary missing required field: #field#" );
        }
      }
    }

    for ( var key in dictionary ) {
      // confirm that key is a valid one based on variables.dictionaries
      if ( structFieldExists && !( arrayFindNoCase( variables.dictionaryFields[ name ].required, key ) || arrayFindNoCase( variables.dictionaryFields[ name ].optional, key ) ) ) {
        throwError( "'#name#' dictionary has invalid field: #key#" );
      }

      //key = newcontact
      if ( isStruct( dictionary[ key ] ) ) {
        structInsert(result, key, parseDictionary( dictionary[ key ], key ) );
      } else if ( isArray( dictionary[ key ] ) ) {

      	structInsert( result, key, [] );
        for ( var item in parseArray( dictionary[ key ], key, name != 'properties' && name != 'fieldValues' ) ) {
          arrayAppend(result[key], item );
        }

      } else {
        // note: for now, the validate param passed into getValidatedParam() is always true, but that can be modified, if necessary
        	structInsert( result, key, getValidatedParam( key, dictionary[ key ] ) );
      }

    }

    return result;
  }

  private array function parseArray( required array list, string name = '', boolean validate = true ) {
    var result = [ ];
    var arrayFieldExists = arrayFindNoCase( variables.arrayFields, name );

    if ( !arrayFieldExists && validate  ) {
      throwError( "'#name#' is not an allowed list variable." );
    }

    for ( var item in list ) {
      if ( isStruct( item ) ) {
        arrayAppend( result, parseDictionary( item, name ) );
      } else if ( isArray( item ) ) {
        arrayAppend( result, parseArray( item, name ) );
      } else {
        arrayAppend( result, getValidatedParam( name, item ) );
      }
    }

    return result;
  }

  private any function getValidatedParam( required string paramName, required any paramValue, boolean validate = true ) {
    // only simple values
    if ( !isSimpleValue( paramValue ) ) throwError( "'#paramName#' is not a simple value." );

    // if not validation just result trimmed value
    if ( !validate ) {
      return trim( paramValue );
    }

    // integer
    if ( arrayFindNoCase( variables.integerFields, paramName ) ) {
      if ( !isInteger( paramValue ) ) {
        throwError( "field '#paramName#' requires an integer value" );
      }
      return paramValue;
    }
    // numeric
    if ( arrayFindNoCase( variables.numericFields, paramName ) ) {
      if ( !isNumeric( paramValue ) ) {
        throwError( "field '#paramName#' requires a numeric value" );
      }
      return paramValue;
    }

    // boolean
    if ( arrayFindNoCase( variables.booleanFields, paramName ) ) {
      return ( paramValue ? "true" : "false" );
    }

    // timestamp
    if ( arrayFindNoCase( variables.timestampFields, paramName ) ) {
      return parseUTCTimestampField( paramValue, paramName );
    }

    // default is string
    return trim( paramValue );
  }

  private void function parseResult( required struct result ) {
    var resultKeys = structKeyArray( result );
    for ( var key in resultKeys ) {
      if ( structKeyExists( result, key ) && !isNull( result[ key ] ) ) {
        if ( isStruct( result[ key ] ) ) parseResult( result[ key ] );
        if ( isArray( result[ key ] ) ) {
          for ( var item in result[ key ] ) {
            if ( isStruct( item ) ) parseResult( item );
          }
        }
        if ( arrayFindNoCase( variables.timestampFields, key ) ) result[ key ] = parseUTCTimestamp( result[ key ] );
      }
    }
  }

  private any function parseUTCTimestampField( required any utcField, required string utcFieldName ) {
    if ( isInteger( utcField ) ) return utcField;
    if ( isDate( utcField ) ) return getUTCTimestamp( utcField );
    throwError( "utc timestamp field '#utcFieldName#' is in an invalid format" );
  }

  private numeric function getUTCTimestamp( required date dateToConvert ) {
    return dateDiff( "s", variables.utcBaseDate, (dateToConvert*1000) );
  }

  private date function parseUTCTimestamp( required any utcTimestamp ) {
    //account for list field values returned within arrays
    var dateToParse = isNumeric( utcTimestamp ) ? utcTimestamp : utcTimestamp[1].raw;
    return dateAdd( "s", (dateToParse/1000), variables.utcBaseDate );
  }

  private boolean function isInteger( required any varToValidate ) {
    return ( isNumeric( varToValidate ) && isValid( "integer", varToValidate ) );
  }

  private string function encodeurl( required string str ) {
    return replacelist( urlEncodedFormat( str, "utf-8" ), "%2D,%2E,%5F,%7E", "-,.,_,~" );
  }

  private void function throwError( required string errorMessage ) {
    throw( type = "SalesForceIQ", message = "(salesforceIQ.cfc) " & errorMessage );
  }

}
