xquery version "3.1";

module namespace authcheck = "http://hra.uni-heidelberg.de/ns/authcheck/";

declare variable $authcheck:delimiter :=  ",";

declare function authcheck:split-csv-line($line) {
    for $record in analyze-string($line, '("(?:[^"]|"")*"|[^' || $authcheck:delimiter ||  '"\n\r]*)(' || $authcheck:delimiter ||  '|\r?\n|\r)')/fn:match/fn:group[. != ',']
    let $record-1 := replace($record, "^&quot;|&quot;$", "")
    let $record-2 := replace($record-1, "&quot;&quot;", "&quot;")
    
    return $record-2
};

declare function authcheck:get-ids($search-string) {
    string-join((authcheck:get-viaf-ids($search-string), authcheck:get-wikidata-ids($search-string)), " ")
};

declare function authcheck:get-viaf-ids($search-string) {
    let $search-string-1 := replace($search-string, "^&quot;|&quot;$", "")
    let $search-string-2 := replace($search-string-1, "&quot;&quot;", "&quot;")
    let $encoded-search-string := xmldb:encode($search-string-2)
    let $url := xs:anyURI("http://viaf.org/viaf/AutoSuggest?query=" || $encoded-search-string)
    let $request-result := util:binary-to-string(xs:base64Binary(httpclient:get($url, true(), ())//httpclient:body))
    let $processed-request-result := "{&quot;query&quot;:" || "&quot;" || replace($search-string-2, "&quot;", "\\&quot;") || "&quot;" || ",&quot;result&quot;:" || substring-after($request-result, ",&quot;result&quot;:")
    let $result := parse-json($processed-request-result)?result?*[?nametype = 'personal']
    
    
    return distinct-values(
        for $item in $result
        let $displayForm := encode-for-uri($item?displayForm)
        let $viaf-ids := $item?viafid ! string-join(("urn:viaf", $displayForm, .), ":")
        let $dnb-ids := $item?dnb ! string-join(("urn:dnb", $displayForm, .), ":")
        
        return ($viaf-ids, $dnb-ids)
    )
};

declare function authcheck:get-wikidata-ids($search-string) {
    let $search-string-1 := replace($search-string, "^&quot;|&quot;$", "")
    let $search-string-2 := replace($search-string-1, "&quot;&quot;", "&quot;")
    let $encoded-search-string := xmldb:encode($search-string-2)
    let $url-1 := xs:anyURI("https://www.wikidata.org/w/api.php?action=wbsearchentities&amp;language=en&amp;format=json&amp;search=" || $encoded-search-string)
    let $ids := string-join(json-doc($url-1)?search?*?id, "|")
    let $result-1 := map:new(
        for $entity in json-doc($url-1)?search?*
    
        return map:entry($entity?id, string-join(($entity?label, $entity?description), " - "))    
    )
    
    let $url-2 := "https://www.wikidata.org/w/api.php?action=wbgetentities&amp;props=claims&amp;format=json&amp;ids=" || $ids
    let $entities := json-doc($url-2)?entities
    
    return
        for $claim-occurence in $entities?*?claims?P31?*
        let $id := substring-before($claim-occurence?id, "$")
        let $claim-value := $claim-occurence?mainsnak?datavalue?value?id
        
        return
            if ($claim-value = "Q5")
            then string-join(("urn:wikidata", encode-for-uri(map:get($result-1, $id)), $id), ":")
            else ()
};

declare function authcheck:process-file($url) {
    let $lines := unparsed-text-lines($url)
    
    return map {
        "data": array {
            for $line in $lines
            let $records := authcheck:split-csv-line($line || ",")
            let $viaf-ids := authcheck:get-viaf-ids($records[2])
            
            return array {$records, $viaf-ids}
        }
    }
};

declare function authcheck:process-uploaded-file($collection, $filename, $uploaded-file) {
    let $store := xmldb:store($collection, $filename, $uploaded-file)
    let $lines := unparsed-text-lines($store)
    let $delete := xmldb:remove($collection, $filename)
    
    return array {
        for $line in $lines
        let $records := authcheck:split-csv-line($line || ",")
        let $viaf-ids := authcheck:get-ids($records[2])
        
        return array {$records, $viaf-ids}
    }
};

