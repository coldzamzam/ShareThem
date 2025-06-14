//
//  Generated code. Do not modify.
//  source: packet.proto
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

@$core.Deprecated('Use ePacketTypeDescriptor instead')
const EPacketType$json = {
  '1': 'EPacketType',
  '2': [
    {'1': 'None', '2': 0},
    {'1': 'GetSharedFilesReq', '2': 1},
    {'1': 'GetSharedFilesRsp', '2': 2},
    {'1': 'SharedFileContentNotify', '2': 3},
    {'1': 'FileTransferCompleteNotify', '2': 4},
  ],
};

/// Descriptor for `EPacketType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List ePacketTypeDescriptor = $convert.base64Decode(
    'CgtFUGFja2V0VHlwZRIICgROb25lEAASFQoRR2V0U2hhcmVkRmlsZXNSZXEQARIVChFHZXRTaG'
    'FyZWRGaWxlc1JzcBACEhsKF1NoYXJlZEZpbGVDb250ZW50Tm90aWZ5EAMSHgoaRmlsZVRyYW5z'
    'ZmVyQ29tcGxldGVOb3RpZnkQBA==');

