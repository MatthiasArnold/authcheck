xquery version "3.1";

import module namespace authcheck = "http://hra.uni-heidelberg.de/ns/authcheck/" at "authcheck.xqm";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "json";
declare option output:media-type "application/json";

(:let $output := authcheck:process-file("/apps/chinese-comics/tests/resources/Agents_extract-select01_2018-06-07.csv"):)
let $base-collection := "/apps/chinese-comics/tests/resources/"
let $tmp-collection := $base-collection || "tmp"
let $output := authcheck:process-uploaded-file($tmp-collection, request:get-uploaded-file-name('file'), request:get-uploaded-file-data('file'))


return $output
