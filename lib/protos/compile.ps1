$SRC_DIR = Split-Path $MyInvocation.MyCommand.Path -Parent
$user = $env:USERNAME
protoc --proto_path=$SRC_DIR --dart_out=$SRC_DIR $SRC_DIR/sharethem.proto