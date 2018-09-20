xquery version "3.1";

module namespace authcheck = "http://hra.uni-heidelberg.de/ns/authcheck/";

declare variable $authcheck:delimiter :=  ",";

declare function authcheck:split-csv-line($line) {
    for $record in analyze-string($line, '("(?:[^"]|"")*"|[^' || $authcheck:delimiter ||  '"\n\r]*)(' || $authcheck:delimiter ||  '|\r?\n|\r)')/fn:match/fn:group[. != ',']
    let $record-1 := replace($record, "^&quot;|&quot;$", "")
    let $record-2 := replace($record-1, "&quot;&quot;", "&quot;")
    
    return $record-2
};

declare function authcheck:get-viaf-ids($search-string) {
    let $search-string-1 := replace($search-string, "^&quot;|&quot;$", "")
    let $search-string-2 := replace($search-string-1, "&quot;&quot;", "&quot;")
    let $encoded-search-string := xmldb:encode($search-string-2)
    let $url := xs:anyURI("http://viaf.org/viaf/AutoSuggest?query=" || $encoded-search-string)
    let $request-result := util:binary-to-string(xs:base64Binary(httpclient:get($url, true(), ())//httpclient:body))
    let $processed-request-result := "{&quot;query&quot;:" || "&quot;" || replace($search-string-2, "&quot;", "\\&quot;") || "&quot;" || ",&quot;result&quot;:" || substring-after($request-result, ",&quot;result&quot;:")
    let $result := parse-json($processed-request-result)?result?*[?nametype = 'personal']
    
    
    return string-join(
        distinct-values(
            for $item in $result
            let $displayForm := encode-for-uri($item?displayForm)
            let $viaf-ids := $item?viafid ! string-join(("urn:viaf", $displayForm, .), ":")
            let $dnb-ids := $item?dnb ! string-join(("urn:dnb", $displayForm, .), ":")
            
            return string-join(($viaf-ids, $dnb-ids), " ")
        )
    , " ")
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
    
    return array {
        for $line in $lines
        let $records := authcheck:split-csv-line($line || ",")
        let $viaf-ids := authcheck:get-viaf-ids($records[2])
        
        return array {$records, $viaf-ids}
    }
};

