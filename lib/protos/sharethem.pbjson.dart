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

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use sharedFileContentNotifyDescriptor instead')
const SharedFileContentNotify$json = {
  '1': 'SharedFileContentNotify',
  '2': [
    {'1': 'file', '3': 1, '4': 1, '5': 11, '6': '.SharedFile', '10': 'file'},
    {'1': 'content', '3': 4, '4': 1, '5': 12, '10': 'content'},
  ],
};

/// Descriptor for `SharedFileContentNotify`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sharedFileContentNotifyDescriptor = $convert.base64Decode(
    'ChdTaGFyZWRGaWxlQ29udGVudE5vdGlmeRIfCgRmaWxlGAEgASgLMgsuU2hhcmVkRmlsZVIEZm'
    'lsZRIYCgdjb250ZW50GAQgASgMUgdjb250ZW50');

@$core.Deprecated('Use getSharedFilesRspDescriptor instead')
const GetSharedFilesRsp$json = {
  '1': 'GetSharedFilesRsp',
  '2': [
    {'1': 'files', '3': 1, '4': 3, '5': 11, '6': '.SharedFile', '10': 'files'},
  ],
};

/// Descriptor for `GetSharedFilesRsp`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getSharedFilesRspDescriptor = $convert.base64Decode(
    'ChFHZXRTaGFyZWRGaWxlc1JzcBIhCgVmaWxlcxgBIAMoCzILLlNoYXJlZEZpbGVSBWZpbGVz');

@$core.Deprecated('Use sharedFileDescriptor instead')
const SharedFile$json = {
  '1': 'SharedFile',
  '2': [
    {'1': 'file_name', '3': 1, '4': 1, '5': 9, '10': 'fileName'},
    {'1': 'file_size', '3': 2, '4': 1, '5': 13, '10': 'fileSize'},
    {'1': 'file_crc', '3': 3, '4': 1, '5': 13, '10': 'fileCrc'},
  ],
};

/// Descriptor for `SharedFile`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sharedFileDescriptor = $convert.base64Decode(
    'CgpTaGFyZWRGaWxlEhsKCWZpbGVfbmFtZRgBIAEoCVIIZmlsZU5hbWUSGwoJZmlsZV9zaXplGA'
    'IgASgNUghmaWxlU2l6ZRIZCghmaWxlX2NyYxgDIAEoDVIHZmlsZUNyYw==');

@$core.Deprecated('Use getSharedFilesReqDescriptor instead')
const GetSharedFilesReq$json = {
  '1': 'GetSharedFilesReq',
};

/// Descriptor for `GetSharedFilesReq`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getSharedFilesReqDescriptor = $convert.base64Decode(
    'ChFHZXRTaGFyZWRGaWxlc1JlcQ==');

@$core.Deprecated('Use sharedFileCompletedNotifyDescriptor instead')
const SharedFileCompletedNotify$json = {
  '1': 'SharedFileCompletedNotify',
  '2': [
    {'1': 'file_name', '3': 1, '4': 1, '5': 9, '10': 'fileName'},
    {'1': 'success', '3': 2, '4': 1, '5': 8, '10': 'success'},
    {'1': 'message', '3': 3, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `SharedFileCompletedNotify`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sharedFileCompletedNotifyDescriptor = $convert.base64Decode(
    'ChlTaGFyZWRGaWxlQ29tcGxldGVkTm90aWZ5EhsKCWZpbGVfbmFtZRgBIAEoCVIIZmlsZU5hbW'
    'USGAoHc3VjY2VzcxgCIAEoCFIHc3VjY2VzcxIYCgdtZXNzYWdlGAMgASgJUgdtZXNzYWdl');

@$core.Deprecated('Use fileChunkDescriptor instead')
const FileChunk$json = {
  '1': 'FileChunk',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'file_name', '3': 2, '4': 1, '5': 9, '10': 'fileName'},
    {'1': 'file_size', '3': 3, '4': 1, '5': 13, '10': 'fileSize'},
    {'1': 'file_crc', '3': 4, '4': 1, '5': 13, '10': 'fileCrc'},
    {'1': 'chunk_data', '3': 5, '4': 1, '5': 12, '10': 'chunkData'},
  ],
};

/// Descriptor for `FileChunk`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List fileChunkDescriptor = $convert.base64Decode(
    'CglGaWxlQ2h1bmsSHQoKc2Vzc2lvbl9pZBgBIAEoCVIJc2Vzc2lvbklkEhsKCWZpbGVfbmFtZR'
    'gCIAEoCVIIZmlsZU5hbWUSGwoJZmlsZV9zaXplGAMgASgNUghmaWxlU2l6ZRIZCghmaWxlX2Ny'
    'YxgEIAEoDVIHZmlsZUNyYxIdCgpjaHVua19kYXRhGAUgASgMUgljaHVua0RhdGE=');

@$core.Deprecated('Use fileSendResponseDescriptor instead')
const FileSendResponse$json = {
  '1': 'FileSendResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
    {'1': 'file_name', '3': 3, '4': 1, '5': 9, '10': 'fileName'},
  ],
};

/// Descriptor for `FileSendResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List fileSendResponseDescriptor = $convert.base64Decode(
    'ChBGaWxlU2VuZFJlc3BvbnNlEhgKB3N1Y2Nlc3MYASABKAhSB3N1Y2Nlc3MSGAoHbWVzc2FnZR'
    'gCIAEoCVIHbWVzc2FnZRIbCglmaWxlX25hbWUYAyABKAlSCGZpbGVOYW1l');

const $core.Map<$core.String, $core.dynamic> ShareThemServiceBase$json = {
  '1': 'ShareThem',
  '2': [
    {'1': 'GetSharedFiles', '2': '.GetSharedFilesReq', '3': '.GetSharedFilesRsp'},
    {'1': 'SendFile', '2': '.FileChunk', '3': '.FileSendResponse', '5': true, '6': true},
    {'1': 'StreamFileToReceiver', '2': '.SharedFileContentNotify', '3': '.SharedFileCompletedNotify', '5': true},
  ],
};

@$core.Deprecated('Use shareThemServiceDescriptor instead')
const $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>> ShareThemServiceBase$messageJson = {
  '.GetSharedFilesReq': GetSharedFilesReq$json,
  '.GetSharedFilesRsp': GetSharedFilesRsp$json,
  '.SharedFile': SharedFile$json,
  '.FileChunk': FileChunk$json,
  '.FileSendResponse': FileSendResponse$json,
  '.SharedFileContentNotify': SharedFileContentNotify$json,
  '.SharedFileCompletedNotify': SharedFileCompletedNotify$json,
};

/// Descriptor for `ShareThem`. Decode as a `google.protobuf.ServiceDescriptorProto`.
final $typed_data.Uint8List shareThemServiceDescriptor = $convert.base64Decode(
    'CglTaGFyZVRoZW0SOAoOR2V0U2hhcmVkRmlsZXMSEi5HZXRTaGFyZWRGaWxlc1JlcRoSLkdldF'
    'NoYXJlZEZpbGVzUnNwEi0KCFNlbmRGaWxlEgouRmlsZUNodW5rGhEuRmlsZVNlbmRSZXNwb25z'
    'ZSgBMAESTgoUU3RyZWFtRmlsZVRvUmVjZWl2ZXISGC5TaGFyZWRGaWxlQ29udGVudE5vdGlmeR'
    'oaLlNoYXJlZEZpbGVDb21wbGV0ZWROb3RpZnkoAQ==');

