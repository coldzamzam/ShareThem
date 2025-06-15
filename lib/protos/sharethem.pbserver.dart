//
//  Generated code. Do not modify.
//  source: lib/protos/sharethem.proto
//
// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'sharethem.pb.dart' as $0;
import 'sharethem.pbjson.dart';

export 'sharethem.pb.dart';

abstract class ShareThemServiceBase extends $pb.GeneratedService {
  $async.Future<$0.GetSharedFilesRsp> getSharedFiles($pb.ServerContext ctx, $0.GetSharedFilesReq request);
  $async.Future<$0.FileSendResponse> sendFile($pb.ServerContext ctx, $0.FileChunk request);
  $async.Future<$0.SharedFileCompletedNotify> streamFileToReceiver($pb.ServerContext ctx, $0.SharedFileContentNotify request);

  $pb.GeneratedMessage createRequest($core.String methodName) {
    switch (methodName) {
      case 'GetSharedFiles': return $0.GetSharedFilesReq();
      case 'SendFile': return $0.FileChunk();
      case 'StreamFileToReceiver': return $0.SharedFileContentNotify();
      default: throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $async.Future<$pb.GeneratedMessage> handleCall($pb.ServerContext ctx, $core.String methodName, $pb.GeneratedMessage request) {
    switch (methodName) {
      case 'GetSharedFiles': return getSharedFiles(ctx, request as $0.GetSharedFilesReq);
      case 'SendFile': return sendFile(ctx, request as $0.FileChunk);
      case 'StreamFileToReceiver': return streamFileToReceiver(ctx, request as $0.SharedFileContentNotify);
      default: throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $core.Map<$core.String, $core.dynamic> get $json => ShareThemServiceBase$json;
  $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>> get $messageJson => ShareThemServiceBase$messageJson;
}

