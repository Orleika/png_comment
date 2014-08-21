require "pngood.pl";

$pngFile = "a.png";
$comment = "building";
$newFile = "a_c.png";

$result = pngood::inserter($pngFile, $comment, $newFile);
echo $result;
