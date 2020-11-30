xquery version "3.1";

declare variable $home external;
declare variable $target external;

(
	xmldb:create-collection($target, "tmp")
	,
    (: set special permissions for xquery scripts :)
    sm:chmod(xs:anyURI($target || "/modules/check-ids/check-ids.xql"), "rwsr-xr-x")
)
