//
//  Generated code. Do not modify.
//  source: sharethem.proto
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

